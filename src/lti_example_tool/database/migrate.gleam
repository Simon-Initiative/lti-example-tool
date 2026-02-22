import argv
import gleam/dynamic/decode
import gleam/erlang/application
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/result
import gleam/string
import lightbulb/jwk
import lti_example_tool/config
import lti_example_tool/database
import lti_example_tool/jwks
import lti_example_tool/seeds
import lti_example_tool/utils/logger
import pog
import shellout

pub fn main() {
  logger.configure_backend()

  case argv.load().arguments {
    ["up"] -> {
      let assert Ok(_db_config) = start_db("migrate_pool")

      let assert Ok(result) = run_migrate_command("up")

      io.println(result)

      Nil
    }
    ["down"] -> {
      let assert Ok(_db_config) = start_db("migrate_pool")

      let assert Ok(result) = run_migrate_command("down")

      io.println(result)

      Nil
    }
    ["status"] -> {
      let assert Ok(_db_config) = start_db("migrate_pool")

      let assert Ok(result) = run_migrate_command("status")

      io.println(result)

      Nil
    }
    ["create", ..args] -> {
      case args {
        [name, ..] -> {
          let assert Ok(_) = create_migration(name)

          Nil
        }
        _ -> {
          io.println(
            "usage: gleam run -m lti_example_tool/database/migrate create [name]",
          )
        }
      }
    }
    ["seed"] -> {
      let assert Ok(db_config) = start_db("migrate_pool")

      let db = pog.named_connection(db_config.pool_name)

      let assert Ok(_) = seed(db)

      Nil
    }
    ["setup"] -> {
      let assert Ok(db_config) =
        start_db_with("migrate_pool", fn(config) {
          config |> pog.database("postgres")
        })

      let assert Ok(database_url) = database_url_for(db_config.database)

      setup(db_config, database_url)
    }
    ["test.setup"] -> {
      let assert Ok(db_config) =
        start_db_with("migrate_pool", fn(config) {
          config |> pog.database("postgres")
        })

      let test_db_config = test_db_config(db_config)
      let assert Ok(test_database_url) =
        database_url_for(test_db_config.database)

      setup(test_db_config, test_database_url)
    }
    ["reset"] -> {
      let assert Ok(db_config) =
        start_db_with("migrate_pool", fn(config) {
          config |> pog.database("postgres")
        })

      let assert Ok(database_url) = database_url_for(db_config.database)

      let assert Ok(_) = reset(db_config, database_url)
      Nil
    }
    ["test.reset"] -> {
      let assert Ok(db_config) =
        start_db_with("migrate_pool", fn(config) {
          config |> pog.database("postgres")
        })

      let test_db_config = test_db_config(db_config)
      let assert Ok(test_database_url) =
        database_url_for(test_db_config.database)

      let assert Ok(_) = reset(test_db_config, test_database_url)

      Nil
    }
    _ ->
      io.println(
        "usage: gleam run -m lti_example_tool/database/migrate [up|down|status|create|seed|setup|test.setup|reset|test.reset]",
      )
  }

  sleep(10)
}

fn start_db(db_pool_name) {
  let url = config.database_url()

  use db_config <- result.try(
    process.new_name(db_pool_name)
    |> pog.url_config(url)
    |> result.map_error(string.inspect),
  )

  let assert Ok(_) = start_connection_with_retry(db_config, 20)

  Ok(db_config)
}

fn start_db_with(db_pool_name, map_config: fn(pog.Config) -> pog.Config) {
  let url = config.database_url()

  use db_config <- result.try(
    process.new_name(db_pool_name)
    |> pog.url_config(url)
    |> result.map_error(string.inspect),
  )

  let assert Ok(_) = start_connection_with_retry(map_config(db_config), 20)

  Ok(db_config)
}

fn start_connection_with_retry(db_config: pog.Config, attempts_left: Int) {
  case pog.start(db_config) {
    Ok(started) -> Ok(started)
    Error(error) -> {
      case attempts_left <= 1 {
        True -> {
          logger.error_meta(
            "Failed to connect to database after retries",
            error,
          )
          Error(error)
        }
        False -> {
          logger.warn(
            "Database is not ready yet. Retrying connection ("
            <> int.to_string(attempts_left - 1)
            <> " attempts remaining)...",
          )
          sleep(1000)
          start_connection_with_retry(db_config, attempts_left - 1)
        }
      }
    }
  }
}

@external(erlang, "timer", "sleep")
fn sleep(time_ms: Int) -> Nil

pub fn maybe_initialize_db(db_config: pog.Config) {
  case db_exists(db_config) {
    True -> {
      logger.debug("Database '" <> db_config.database <> "' exists.")

      Nil
    }
    False -> {
      logger.info(
        "Database '"
        <> db_config.database
        <> "' does not exist. Running database initialization...",
      )
      let assert Ok(database_url) = database_url_for(db_config.database)
      setup(db_config, database_url)
    }
  }
}

fn db_exists(db_config: pog.Config) -> Bool {
  let db_name = db_config.database

  logger.debug("Checking if database '" <> db_name <> "' exists...")

  let db = pog.named_connection(db_config.pool_name)

  let returned =
    "SELECT 1 FROM pg_database WHERE datname::text = $1;"
    |> pog.query()
    |> pog.parameter(pog.text(db_name))
    |> pog.returning(decode.at([0], decode.int))
    |> pog.execute(db)
    |> database.one()

  case returned {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn test_db_config(db_config: pog.Config) -> pog.Config {
  pog.Config(..db_config, database: db_config.database <> "_test")
}

fn database_url_for(database_name: String) -> Result(String, String) {
  let database_url = config.database_url()
  use db_config <- result.try(
    process.new_name("migrate_url_pool")
    |> pog.url_config(database_url)
    |> result.map_error(string.inspect),
  )

  let source_database = "/" <> db_config.database
  let target_database = "/" <> database_name

  case string.contains(database_url, source_database <> "?") {
    True ->
      Ok(string.replace(
        in: database_url,
        each: source_database <> "?",
        with: target_database <> "?",
      ))
    False ->
      Ok(string.replace(
        in: database_url,
        each: source_database,
        with: target_database,
      ))
  }
}

fn setup(db_config: pog.Config, database_url: String) {
  create_database(db_config)

  let assert Ok(_) = run_migrate_command_with("up", database_url)
  let _ = seed_database(db_config)

  Nil
}

fn create_database(db_config: pog.Config) {
  let db_name = db_config.database

  logger.info("Creating database '" <> db_name <> "'...")

  let db = pog.named_connection(db_config.pool_name)

  let sql = "CREATE DATABASE " <> db_name <> ";"
  let assert Ok(_) =
    pog.query(sql)
    |> pog.returning(decode.dynamic)
    |> pog.execute(db)

  logger.info("Database created.")
}

fn drop_database(db_config: pog.Config) {
  let db_name = db_config.database

  logger.info("Dropping database '" <> db_name <> "'...")

  let db = pog.named_connection(db_config.pool_name)

  let sql = "DROP DATABASE IF EXISTS " <> db_name <> ";"
  let assert Ok(_) =
    pog.query(sql)
    |> pog.returning(decode.dynamic)
    |> pog.execute(db)

  logger.info("Database dropped.")
}

fn reset(db_config: pog.Config, database_url: String) {
  drop_database(db_config)
  create_database(db_config)

  use _ <- result.try(run_migrate_command_with("up", database_url))
  let _ = seed_database(db_config)

  logger.info("Database reset.")

  Ok(Nil)
}

fn seed_database(db_config: pog.Config) -> Result(Nil, String) {
  let seed_pool_name = process.new_name("migrate_seed_pool")
  let seed_db_config = pog.Config(..db_config, pool_name: seed_pool_name)

  use started <- result.try(
    start_connection_with_retry(seed_db_config, 20)
    |> result.map_error(string.inspect),
  )

  seed(started.data)
}

fn seed(db: pog.Connection) -> Result(Nil, String) {
  logger.info("Seeding database...")

  use active_jwk <- result.try(
    jwk.generate()
    |> result.map_error(fn(e) {
      "Failed to generate JWK: " <> string.inspect(e)
    }),
  )

  use _ <- result.try(
    jwks.insert(db, active_jwk) |> result.map_error(database.humanize_error),
  )

  use _ <- result.try(
    jwks.set_active_jwk(db, active_jwk.kid)
    |> result.map_error(database.humanize_error),
  )

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

fn run_migrate_command(command: String) -> Result(String, String) {
  run_migrate_command_with(command, config.database_url())
}

fn run_migrate_command_with(
  command: String,
  database_url: String,
) -> Result(String, String) {
  case shellout.which("goose") {
    Ok(goose) -> {
      let goose_args = [
        "-dir",
        migrations_dir(),
        "postgres",
        database_url,
        command,
      ]

      shellout.command(
        run: goose,
        with: goose_args,
        in: migrations_dir(),
        opt: [],
      )
      |> result.map_error(fn(err) {
        "Command execution failed: " <> string.inspect(err)
      })
    }
    Error(_) -> Error("Failed to find executable: goose")
  }
}

fn create_migration(name: String) -> Result(String, String) {
  case shellout.which("goose") {
    Ok(goose) -> {
      let goose_args = ["-dir", migrations_dir(), "create", name, "sql"]

      shellout.command(
        run: goose,
        with: goose_args,
        in: migrations_dir(),
        opt: [],
      )
      |> result.map_error(fn(err) {
        "Command execution failed: " <> string.inspect(err)
      })
    }
    Error(_) -> Error("Failed to find executable: goose")
  }
}

fn migrations_dir() {
  let assert Ok(priv_dir) = application.priv_directory("lti_example_tool")

  priv_dir <> "/repo/migrations"
}
