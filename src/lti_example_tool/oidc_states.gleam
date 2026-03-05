import gleam/dynamic/decode
import gleam/result
import gleam/time/timestamp
import lightbulb/providers/data_provider.{
  type LaunchContextError, type LoginContext, LaunchContextInvalid,
  LaunchContextNotFound, LoginContext,
}
import lti_example_tool/database.{type Database, one}
import lti_example_tool/utils/logger
import pog

fn login_context_decoder() -> decode.Decoder(LoginContext) {
  use state <- decode.field(0, decode.string)
  use target_link_uri <- decode.field(1, decode.string)
  use issuer <- decode.field(2, decode.string)
  use client_id <- decode.field(3, decode.string)
  use expires_at <- decode.field(4, pog.timestamp_decoder())

  decode.success(LoginContext(
    state: state,
    target_link_uri: target_link_uri,
    issuer: issuer,
    client_id: client_id,
    expires_at: expires_at,
  ))
}

pub fn save_login_context(
  db: Database,
  context: LoginContext,
) -> Result(Nil, LaunchContextError) {
  "INSERT INTO oidc_states (state, target_link_uri, issuer, client_id, expires_at) VALUES ($1, $2, $3, $4, $5)"
  |> pog.query()
  |> pog.parameter(pog.text(context.state))
  |> pog.parameter(pog.text(context.target_link_uri))
  |> pog.parameter(pog.text(context.issuer))
  |> pog.parameter(pog.text(context.client_id))
  |> pog.parameter(pog.timestamp(context.expires_at))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    logger.error_meta("Failed to persist login context", e)

    LaunchContextInvalid
  })
}

pub fn get_login_context(
  db: Database,
  state: String,
) -> Result(LoginContext, LaunchContextError) {
  "SELECT state, target_link_uri, issuer, client_id, expires_at
   FROM oidc_states
   WHERE state = $1 AND expires_at > $2"
  |> pog.query()
  |> pog.parameter(pog.text(state))
  |> pog.parameter(pog.timestamp(timestamp.system_time()))
  |> pog.returning(login_context_decoder())
  |> pog.execute(db)
  |> one()
  |> result.map_error(fn(_) { LaunchContextNotFound })
}

/// Consumes state exactly once and only if it has not expired.
pub fn consume_login_context(
  db: Database,
  state: String,
) -> Result(Nil, LaunchContextError) {
  "DELETE FROM oidc_states WHERE state = $1 AND expires_at > $2 RETURNING state"
  |> pog.query()
  |> pog.parameter(pog.text(state))
  |> pog.parameter(pog.timestamp(timestamp.system_time()))
  |> pog.returning(decode.at([0], decode.string))
  |> pog.execute(db)
  |> one()
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(_) { LaunchContextNotFound })
}

pub fn cleanup_expired_states(db: Database) {
  "DELETE FROM oidc_states WHERE expires_at < $1"
  |> pog.query()
  |> pog.parameter(pog.timestamp(timestamp.system_time()))
  |> pog.execute(db)
}
