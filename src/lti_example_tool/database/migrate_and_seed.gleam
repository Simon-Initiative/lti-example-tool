import argv
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/result
import gleam/set
import lti_example_tool/database
import lti_example_tool/seeds
import lti_example_tool/utils/logger
import pog.{type Connection, type Returned}

pub fn main() {
  logger.configure_backend()

  case argv.load().arguments {
    ["migrate"] -> {
      let db = database.connect("lti_example_tool")

      let assert Ok(_) = migrate(db)

      database.disconnect(db)

      Nil
    }
    ["seed"] -> {
      let db = database.connect("lti_example_tool")

      let _ = seed(db)

      database.disconnect(db)

      Nil
    }
    ["setup"] -> {
      create_database("lti_example_tool")

      let db = database.connect("lti_example_tool")

      let assert Ok(_) = migrate(db)
      let _ = seed(db)

      database.disconnect(db)

      Nil
    }
    ["reset"] -> {
      let assert Ok(_) = reset("lti_example_tool")

      Nil
    }
    ["test.reset"] -> {
      let assert Ok(_) = reset("lti_example_tool_test")

      Nil
    }
    _ ->
      io.println(
        "usage: gleam run -m lti_example_tool/database/migrate_and_seed [migrate|seed|setup|reset]",
      )
  }

  sleep(10)
}

@external(erlang, "timer", "sleep")
fn sleep(time_ms: Int) -> Nil

fn create_database(db_name: String) {
  logger.info("Creating database '" <> db_name <> "'...")

  let conn = database.connect("postgres")

  let sql = "CREATE DATABASE " <> db_name <> ";"
  let assert Ok(_) =
    pog.query(sql)
    |> pog.returning(decode.dynamic)
    |> pog.execute(conn)

  database.disconnect(conn)

  logger.info("Database created.")
}

fn drop_database(db_name: String) {
  logger.info("Dropping database '" <> db_name <> "'...")

  let conn = database.connect("postgres")

  let sql = "DROP DATABASE IF EXISTS " <> db_name <> ";"
  let assert Ok(_) =
    pog.query(sql)
    |> pog.returning(decode.dynamic)
    |> pog.execute(conn)

  database.disconnect(conn)

  logger.info("Database dropped.")
}

fn reset(db_name: String) {
  drop_database(db_name)
  create_database(db_name)

  let db = database.connect(db_name)

  use _ <- result.try(migrate(db))
  use _ <- result.try(seed(db))

  database.disconnect(db)

  Ok(Nil)
}

type Migration {
  Migration(
    name: String,
    up: fn(Connection) -> Result(Returned(Dynamic), pog.QueryError),
    down: fn(Connection) -> Result(Returned(Dynamic), pog.QueryError),
  )
}

fn migrate(db: Connection) {
  logger.info("Running migrations...")

  let result = run_migrations(db, lti_example_tool_migrations())

  case result {
    Ok(_) -> {
      logger.info("Migrations completed.")
    }
    Error(_) -> {
      logger.error("Migrations failed.")
    }
  }

  result |> result.replace_error("Failed to run migrations")
}

fn run_migrations(
  db: Connection,
  migrations: List(Migration),
) -> Result(Nil, pog.QueryError) {
  // create migrations table if it doesn't exist
  let assert Ok(_) =
    pog.query(
      "CREATE TABLE IF NOT EXISTS migrations (name TEXT PRIMARY KEY, inserted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
    )
    |> pog.returning(decode.dynamic)
    |> pog.execute(db)

  // get list of migrations that have already been run
  let assert Ok(ran_migrations) =
    pog.query("SELECT name FROM migrations")
    |> pog.returning(decode.at([0], decode.string))
    |> pog.execute(db)

  let ran_migrations_set =
    ran_migrations.rows
    |> set.from_list

  // run any migrations that haven't been run yet
  migrations
  |> list.fold_until(Ok(Nil), fn(_acc, migration) {
    case set.contains(ran_migrations_set, migration.name) {
      True -> {
        // migration has already been run
        Continue(Ok(Nil))
      }
      False -> {
        logger.info("Running migration: " <> migration.name)

        // create a new transaction for running migrations
        let assert Ok(_) =
          pog.query("BEGIN")
          |> pog.returning(decode.dynamic)
          |> pog.execute(db)

        // run migration
        case migration.up(db) {
          Ok(_) -> {
            let assert Ok(_) =
              pog.query("INSERT INTO migrations (name) VALUES ($1)")
              |> pog.parameter(pog.text(migration.name))
              |> pog.returning(decode.dynamic)
              |> pog.execute(db)

            // commit transaction
            let assert Ok(_) =
              pog.query("COMMIT")
              |> pog.returning(decode.dynamic)
              |> pog.execute(db)

            Continue(Ok(Nil))
          }
          Error(e) -> {
            // rollback transaction
            let assert Ok(_) =
              pog.query("ROLLBACK")
              |> pog.returning(decode.dynamic)
              |> pog.execute(db)

            logger.error_meta("Migration failed: " <> migration.name, e)

            Stop(Error(e))
          }
        }
      }
    }
  })
}

fn lti_example_tool_migrations() -> List(Migration) {
  [
    Migration(
      name: "create_registrations_table",
      up: fn(conn) {
        let sql =
          "
          CREATE TABLE registrations (
            id SERIAL PRIMARY KEY,
            name TEXT,
            issuer TEXT,
            client_id TEXT,
            auth_endpoint TEXT,
            access_token_endpoint TEXT,
            keyset_url TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(issuer, client_id)
          );
        "
        pog.query(sql) |> pog.returning(decode.dynamic) |> pog.execute(conn)
      },
      down: fn(conn) {
        let sql =
          "
          DROP TABLE registrations;
        "
        pog.query(sql) |> pog.returning(decode.dynamic) |> pog.execute(conn)
      },
    ),
    Migration(
      name: "create_deployments_table",
      up: fn(conn) {
        let sql =
          "
          CREATE TABLE deployments (
            id SERIAL PRIMARY KEY,
            deployment_id TEXT,
            registration_id INT REFERENCES registrations(id),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(deployment_id, registration_id)
          );
        "
        pog.query(sql) |> pog.returning(decode.dynamic) |> pog.execute(conn)
      },
      down: fn(conn) {
        let sql =
          "
          DROP TABLE deployments;
        "
        pog.query(sql) |> pog.returning(decode.dynamic) |> pog.execute(conn)
      },
    ),
    Migration(
      name: "create_nonces_table",
      up: fn(conn) {
        let sql =
          "
          CREATE TABLE nonces (
            nonce TEXT PRIMARY KEY,
            expires_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(nonce)
          );
        "
        pog.query(sql) |> pog.returning(decode.dynamic) |> pog.execute(conn)
      },
      down: fn(conn) {
        let sql =
          "
          DROP TABLE nonces;
        "
        pog.query(sql) |> pog.returning(decode.dynamic) |> pog.execute(conn)
      },
    ),
  ]
}

fn seed(db: Connection) {
  logger.info("Seeding database...")

  case seeds.load_from_file(db, "seeds.yml") {
    Ok(_) -> {
      logger.info("Database seeded.")

      Ok(Nil)
    }
    Error(e) -> {
      logger.error("Failed to seed database: " <> e)

      Error(e)
    }
  }
}
