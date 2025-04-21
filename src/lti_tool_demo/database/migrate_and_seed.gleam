import argv
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/set
import lti_tool_demo/database
import lti_tool_demo/utils/logger
import pog.{type Connection, type Returned}

pub fn main() {
  logger.configure_backend()

  case argv.load().arguments {
    ["migrate"] -> {
      let db = database.connect("lti_tool_demo")

      migrate(db)

      database.disconnect(db)

      Nil
    }
    ["seed"] -> {
      let db = database.connect("lti_tool_demo")

      seed(db)

      database.disconnect(db)

      Nil
    }
    ["setup"] -> {
      let db = database.connect("lti_tool_demo")

      migrate(db)
      seed(db)

      database.disconnect(db)

      Nil
    }
    ["reset"] -> {
      reset("lti_tool_demo")

      Nil
    }
    ["test.reset"] -> {
      reset("lti_tool_demo_test")

      Nil
    }
    _ ->
      io.println(
        "usage: gleam run -m lti_tool_demo/database/migrate_and_seed [migrate|seed|setup|reset]",
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

  migrate(db)
  seed(db)

  database.disconnect(db)
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

  let result = run_migrations(db, lti_tool_demo_migrations())

  case result {
    Ok(_) -> {
      logger.info("Migrations completed.")
    }
    Error(_) -> {
      logger.error("Migrations failed.")
    }
  }
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

fn lti_tool_demo_migrations() -> List(Migration) {
  [
    Migration(
      name: "create_platforms_table",
      up: fn(conn) {
        let sql =
          "
          CREATE TABLE platforms (
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
          DROP TABLE platforms;
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
            nonce VARCHAR(255) PRIMARY KEY,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
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

  // TODO: read in platform configs from file and insert them into the database

  let sql =
    "
    INSERT INTO platforms (
      name, issuer, client_id, auth_endpoint, access_token_endpoint, keyset_url
    ) VALUES
      ('OLI Torus Platform', 'http://localhost', '10000000001', 'http://localhost/lti/authorize_redirect', 'http://localhost/auth/token', 'http://localhost/.well-known/jwks');
   "

  let assert Ok(_) =
    pog.query(sql) |> pog.returning(decode.dynamic) |> pog.execute(db)

  logger.info("Database seeded.")
}
