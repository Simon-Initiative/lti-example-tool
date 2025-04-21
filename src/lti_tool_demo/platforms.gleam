import gleam/dynamic/decode
import gleam/option.{None, Some}
import gleam/result
import lti_tool_demo/database.{type Database}
import pog

fn platform_decoder() {
  // TODO
  decode.dynamic
}

/// Get all platforms
pub fn all(db: Database) {
  "SELECT * FROM platforms"
  |> pog.query()
  |> pog.returning(platform_decoder())
  |> pog.execute(db)
  |> result.map(fn(response) { response.rows })
}

pub fn get(db: Database, id: Int) {
  "SELECT * FROM platforms WHERE id = $1"
  |> pog.query()
  |> pog.parameter(pog.int(id))
  |> pog.returning(platform_decoder())
  |> pog.execute(db)
  |> result.map(fn(response) {
    case response.rows {
      [row, ..] -> Some(row)
      _ -> None
    }
  })
}
