import birl.{type Time}
import gleam/dynamic/decode
import gleam/option.{Some}
import gleam/result
import gleam/string
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

pub type Record(a) {
  Record(id: Int, created_at: pog.Timestamp, updated_at: pog.Timestamp, data: a)
}

pub type DatabaseError {
  QueryError(e: pog.QueryError)
  ExpectedOneRow
}

pub fn count(query_result: Result(pog.Returned(a), pog.QueryError)) {
  query_result
  |> result.map(fn(returned) { returned.count })
  |> result.map_error(QueryError)
}

pub fn rows(query_result: Result(pog.Returned(a), pog.QueryError)) {
  query_result
  |> result.map(fn(returned) { returned.rows })
  |> result.map_error(QueryError)
}

pub fn one(query_result: Result(pog.Returned(a), pog.QueryError)) {
  query_result
  |> result.map_error(QueryError)
  |> result.then(fn(returned) {
    case returned.rows {
      [row, ..] -> Ok(row)
      _ -> Error(ExpectedOneRow)
    }
  })
}

pub fn humanize_error(error: DatabaseError) {
  case error {
    QueryError(e) -> "Query error: " <> string.inspect(e)
    ExpectedOneRow -> "Expected one row, but got none"
  }
}

pub fn timestamp_from_time(time: Time) -> pog.Timestamp {
  let #(#(year, month, day), #(hour, minute, second)) =
    birl.to_erlang_universal_datetime(time)

  pog.Timestamp(pog.Date(year, month, day), pog.Time(hour, minute, second, 0))
}

pub fn time_from_timestamp(timestamp: pog.Timestamp) -> Time {
  let pog.Date(year, month, day) = timestamp.date
  let pog.Time(hour, minute, second, _u_second) = timestamp.time

  birl.from_erlang_universal_datetime(
    #(#(year, month, day), #(hour, minute, second)),
  )
}
