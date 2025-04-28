import gleam/dynamic/decode
import gleam/option.{Some}
import lti_example_tool/utils/logger
import pog.{type Connection}

pub type Database =
  Connection

pub fn connect(db_name: String) -> Database {
  let db =
    pog.connect(
      pog.Config(
        ..pog.default_config(),
        host: "localhost",
        database: db_name,
        user: "postgres",
        password: Some("postgres"),
      ),
    )

  // verify connection was successful
  case
    pog.query("SELECT 1")
    |> pog.returning(decode.at([0], decode.int))
    |> pog.execute(db)
  {
    Ok(_) -> db
    Error(err) -> {
      logger.error_meta("Failed to connect to database", err)

      panic
    }
  }
}

pub fn disconnect(db: Connection) {
  pog.disconnect(db)
}
