import birl
import birl/duration
import gleam/dynamic/decode
import gleam/result
import ids/uuid
import lightbulb/nonce.{type Nonce, Nonce}
import lti_example_tool/database.{
  type Database, one, rows, time_from_timestamp, timestamp_from_time,
}
import lti_example_tool/utils/logger
import pog

fn nonce_decoder() -> decode.Decoder(Nonce) {
  use nonce <- decode.field(0, decode.string)
  use expires_at <- decode.field(1, pog.timestamp_decoder())

  decode.success(Nonce(nonce, time_from_timestamp(expires_at)))
}

pub fn all(db: Database) {
  "SELECT * FROM nonces"
  |> pog.query()
  |> pog.returning(nonce_decoder())
  |> pog.execute(db)
  |> rows()
}

pub fn get(db: Database, value: String) {
  "SELECT * FROM nonces WHERE nonce = $1"
  |> pog.query()
  |> pog.parameter(pog.text(value))
  |> pog.returning(nonce_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn insert(db: Database, nonce: Nonce) {
  "INSERT INTO nonces (nonce, expires_at) VALUES ($1, $2)"
  |> pog.query()
  |> pog.parameter(pog.text(nonce.nonce))
  |> pog.parameter(pog.timestamp(timestamp_from_time(nonce.expires_at)))
  |> pog.execute(db)
}

pub fn delete(db: Database, value: String) {
  "DELETE FROM nonces WHERE nonce = $1"
  |> pog.query()
  |> pog.parameter(pog.text(value))
  |> pog.execute(db)
}

/// Creates a nonce and stores it in the database
pub fn create(db: Database) -> Result(Nonce, String) {
  use value <- result.try(uuid.generate_v4())
  let expires_at = birl.now() |> birl.add(duration.minutes(5))

  let nonce = Nonce(value, expires_at)

  insert(db, nonce)
  |> result.map(fn(_) { nonce })
  |> result.map_error(fn(e) {
    logger.error_meta("Failed to create nonce", e)

    "Failed to create nonce"
  })
}

/// Validates a nonce by checking if it exists in the database
/// and is not expired. If valid, it deletes the nonce from the database
/// to prevent reuse.
pub fn validate_nonce(db: Database, nonce: String) -> Result(Nil, String) {
  use nonce <- result.try(
    get(db, nonce) |> result.replace_error("Failed to get nonce"),
  )

  // remove the nonce from the database so it can't be reused
  delete(db, nonce.nonce)
  |> result.map(fn(_) { Nil })
  |> result.replace_error("Failed to delete nonce")
}

/// Cleans up expired nonces from the database
/// by deleting all nonces that have expired.
pub fn cleanup_expired_nonces(db: Database) {
  "DELETE FROM nonces WHERE expires_at < $1"
  |> pog.query()
  |> pog.parameter(pog.timestamp(timestamp_from_time(birl.now())))
  |> pog.execute(db)
}
