import birl
import birl/duration
import gleam/dynamic/decode
import gleam/result
import lti_example_tool/database.{type Database, one, timestamp_from_time}
import lti_example_tool/utils/logger
import pog

fn state_decoder() -> decode.Decoder(String) {
  decode.at([0], decode.string)
}

pub fn insert(db: Database, state: String, expires_at: birl.Time) {
  "INSERT INTO oidc_states (state, expires_at) VALUES ($1, $2)"
  |> pog.query()
  |> pog.parameter(pog.text(state))
  |> pog.parameter(pog.timestamp(timestamp_from_time(expires_at)))
  |> pog.execute(db)
}

pub fn create(db: Database, state: String) -> Result(Nil, String) {
  let expires_at = birl.now() |> birl.add(duration.minutes(5))

  insert(db, state, expires_at)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    logger.error_meta("Failed to persist oidc state", e)

    "Failed to persist oidc state"
  })
}

/// Consumes state exactly once and only if it has not expired.
pub fn consume(db: Database, state: String) -> Result(String, String) {
  "DELETE FROM oidc_states WHERE state = $1 AND expires_at > $2 RETURNING state"
  |> pog.query()
  |> pog.parameter(pog.text(state))
  |> pog.parameter(pog.timestamp(timestamp_from_time(birl.now())))
  |> pog.returning(state_decoder())
  |> pog.execute(db)
  |> one()
  |> result.map_error(fn(_) { "Invalid or expired state" })
}

pub fn cleanup_expired_states(db: Database) {
  "DELETE FROM oidc_states WHERE expires_at < $1"
  |> pog.query()
  |> pog.parameter(pog.timestamp(timestamp_from_time(birl.now())))
  |> pog.execute(db)
}
