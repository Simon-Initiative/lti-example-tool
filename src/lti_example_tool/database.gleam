import birl.{type Time}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lti_example_tool/utils/logger
import pog.{type Connection}

pub type Database =
  Connection

pub fn connect(config: pog.Config) -> Database {
  let db = pog.connect(config)

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

pub fn config_from_url(url: String) -> pog.Config {
  let assert Ok(db_config) = pog.url_config(url)

  db_config
}

pub type Record(pk, a) {
  Record(id: pk, created_at: pog.Timestamp, updated_at: pog.Timestamp, data: a)
}

pub type DatabaseError {
  DatabaseError(e: String)
  QueryError(e: pog.QueryError)
  ExpectedSingleRow(num_rows: Int)
  TransactionError(e: pog.TransactionError)
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
      [row] -> Ok(row)
      rows -> Error(ExpectedSingleRow(list.length(rows)))
    }
  })
}

pub fn transaction(db: Database, tx: fn(Database) -> Result(a, DatabaseError)) {
  pog.transaction(db, fn(db) { tx(db) |> result.map_error(string.inspect) })
  |> result.map_error(TransactionError)
}

pub fn savepoint(db: Database, name: String) {
  // create a new savepoint
  let assert Ok(_) =
    pog.query("SAVEPOINT " <> name)
    |> pog.returning(decode.dynamic)
    |> pog.execute(db)
}

pub fn rollback_to_savepoint(db: Database, name: String) {
  // rollback to the savepoint
  let assert Ok(_) =
    pog.query("ROLLBACK TO SAVEPOINT " <> name)
    |> pog.returning(decode.dynamic)
    |> pog.execute(db)
}

pub fn humanize_error(error: DatabaseError) {
  case error {
    DatabaseError(e) -> "Unknown error: " <> e
    QueryError(e) -> "Query error: " <> string.inspect(e)
    ExpectedSingleRow(num_rows) ->
      "Expected a single row but got " <> int.to_string(num_rows) <> " rows"
    TransactionError(e) -> "Transaction error: " <> string.inspect(e)
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
