import argv
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/result
import gleam/set
import gleam/string
import lti/jwk
import lti_example_tool/config
import lti_example_tool/database
import lti_example_tool/jwks
import lti_example_tool/seeds
import lti_example_tool/utils/logger
import pog.{type Connection, type Returned}

pub fn main() {
  logger.configure_backend()

  let db_name = config.db_name()
  let test_db_name = db_name <> "_test"

  case argv.load().arguments {
    ["migrate"] -> {
      let db = database.connect(db_name)

      let assert Ok(_) = migrate(db)

      database.disconnect(db)

      Nil
    }
    ["seed"] -> {
      let db = database.connect(db_name)

      let _ = seed(db)

      database.disconnect(db)

      Nil
    }
    ["setup"] -> {
      create_database(db_name)

      let db = database.connect(db_name)

      let assert Ok(_) = migrate(db)
      let _ = seed(db)

      database.disconnect(db)

      Nil
    }
    ["test.setup"] -> {
      let db_name = config.db_name()
      let test_db_name = db_name <> "_test"

      create_database(test_db_name)

      let db = database.connect(test_db_name)

      let assert Ok(_) = migrate(db)
      let _ = seed(db)

      database.disconnect(db)

      Nil
    }
    ["reset"] -> {
      let assert Ok(_) = reset(db_name)

      Nil
    }
    ["test.reset"] -> {
      let assert Ok(_) = reset(test_db_name)

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

  let _ = seed(db)

  database.disconnect(db)

  logger.info("Database reset.")

  Ok(Nil)
}

type Migration {
  Migration(
    name: String,
    up: fn(Connection) -> Result(Returned(Dynamic), String),
    down: fn(Connection) -> Result(Returned(Dynamic), String),
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
) -> Result(Nil, database.DatabaseError) {
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

        // run migration
        let result =
          database.transaction(db, fn(db) {
            migration.up(db) |> result.map_error(database.DatabaseError)
          })

        case result {
          Ok(_) -> {
            let assert Ok(_) =
              pog.query("INSERT INTO migrations (name) VALUES ($1)")
              |> pog.parameter(pog.text(migration.name))
              |> pog.returning(decode.dynamic)
              |> pog.execute(db)

            Continue(Ok(Nil))
          }
          Error(e) -> {
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
        let assert Ok(_) =
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
          |> pog.query()
          |> pog.returning(decode.dynamic)
          |> pog.execute(conn)
          |> result.map_error(string.inspect)
      },
      down: fn(conn) {
        let assert Ok(_) =
          "
          DROP TABLE registrations;
        "
          |> pog.query()
          |> pog.returning(decode.dynamic)
          |> pog.execute(conn)
          |> result.map_error(string.inspect)
      },
    ),
    Migration(
      name: "create_deployments_table",
      up: fn(conn) {
        let assert Ok(_) =
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
          |> pog.query()
          |> pog.returning(decode.dynamic)
          |> pog.execute(conn)
          |> result.map_error(string.inspect)
      },
      down: fn(conn) {
        let assert Ok(_) =
          "
          DROP TABLE deployments;
        "
          |> pog.query()
          |> pog.returning(decode.dynamic)
          |> pog.execute(conn)
          |> result.map_error(string.inspect)
      },
    ),
    Migration(
      name: "create_nonces_table",
      up: fn(conn) {
        let assert Ok(_) =
          "
          CREATE TABLE nonces (
            nonce TEXT PRIMARY KEY,
            expires_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(nonce)
          );
        "
          |> pog.query()
          |> pog.returning(decode.dynamic)
          |> pog.execute(conn)
          |> result.map_error(string.inspect)
      },
      down: fn(conn) {
        let assert Ok(_) =
          "
          DROP TABLE nonces;
        "
          |> pog.query()
          |> pog.returning(decode.dynamic)
          |> pog.execute(conn)
          |> result.map_error(string.inspect)
      },
    ),
    Migration(
      name: "create_jwks_tables",
      up: fn(conn) {
        let assert Ok(_) =
          database.transaction(conn, fn(conn) {
            "
            CREATE TABLE jwks (
              kid TEXT PRIMARY KEY,
              kty TEXT,
              alg TEXT,
              use TEXT,
              n TEXT,
              e TEXT,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            "
            |> pog.query()
            |> pog.returning(decode.dynamic)
            |> pog.execute(conn)
            |> result.map_error(database.QueryError)
          })
          |> result.map_error(string.inspect)

        let assert Ok(_) =
          database.transaction(conn, fn(conn) {
            "
            CREATE TABLE active_jwk (
              kid TEXT REFERENCES jwks(kid)
            );
            "
            |> pog.query()
            |> pog.returning(decode.dynamic)
            |> pog.execute(conn)
            |> result.map_error(database.QueryError)
          })
          |> result.map_error(string.inspect)
      },
      down: fn(conn) {
        let assert Ok(_) =
          "
          DROP TABLE active_jwk;
        "
          |> pog.query()
          |> pog.returning(decode.dynamic)
          |> pog.execute(conn)
          |> result.map_error(string.inspect)

        let assert Ok(_) =
          "
          DROP TABLE jwks;
        "
          |> pog.query()
          |> pog.returning(decode.dynamic)
          |> pog.execute(conn)
          |> result.map_error(string.inspect)
      },
    ),
  ]
}

fn seed(db: Connection) {
  logger.info("Seeding database...")

  // create active jwk
  use active_jwk <- result.try(jwk.generate())

  let assert Ok(_kid) = jwks.insert(db, active_jwk)
  let assert Ok(_) = jwks.set_active_jwk(db, active_jwk.kid)

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
