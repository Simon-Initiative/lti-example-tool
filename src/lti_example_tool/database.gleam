import birl.{type Time}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp
import lti_example_tool/config
import lti_example_tool/utils/logger
import pog.{type Connection}

pub type Database =
  Connection

pub fn connect() -> Result(Database, String) {
  let url = config.database_url()
  let pool_name = process.new_name("lti_example_tool_db")
  use db_config <- result.try(
    pog.url_config(pool_name, url) |> result.map_error(string.inspect),
  )
  use started <- result.try(
    pog.start(db_config) |> result.map_error(string.inspect),
  )
  let db = started.data

  // verify connection was successful
  case
    pog.query("SELECT 1")
    |> pog.returning(decode.at([0], decode.int))
    |> pog.execute(db)
  {
    Ok(_) -> Ok(db)
    Error(err) -> {
      logger.error_meta("Failed to connect to database", err)

      Error("Failed to connect to database")
    }
  }
}

pub fn disconnect(db: Connection) {
  let _ = db
  Nil
}

pub type Record(pk, a) {
  Record(
    id: pk,
    created_at: timestamp.Timestamp,
    updated_at: timestamp.Timestamp,
    data: a,
  )
}

pub type DatabaseError {
  DatabaseError(e: String)
  QueryError(e: pog.QueryError)
  ExpectedSingleRow(num_rows: Int)
  TransactionError(e: pog.TransactionError(String))
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
  |> result.try(fn(returned) {
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

pub fn timestamp_from_time(time: Time) -> timestamp.Timestamp {
  birl.to_timestamp(time)
}

pub fn time_from_timestamp(timestamp: timestamp.Timestamp) -> Time {
  birl.from_timestamp(timestamp)
}
