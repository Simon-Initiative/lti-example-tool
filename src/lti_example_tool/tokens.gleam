import birl
import birl/duration
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/result
import lti_example_tool/database.{
  type Database, DatabaseError, QueryError, one, timestamp_from_time,
  transaction,
}
import lti_example_tool/utils/logger
import pog
import youid/uuid

pub type TokenType {
  Bootstrap
  Refresh
}

fn token_type_label(token_type: TokenType) -> String {
  case token_type {
    Bootstrap -> "bootstrap"
    Refresh -> "refresh"
  }
}

fn hash_token(raw: String) -> String {
  crypto.hash(crypto.Sha256, <<raw:utf8>>)
  |> bit_array.base16_encode
}

fn token_user_decoder() -> decode.Decoder(#(Int, Int)) {
  use token_id <- decode.field(0, decode.int)
  use user_id <- decode.field(1, decode.int)

  decode.success(#(token_id, user_id))
}

pub fn create_bootstrap_token(
  db: Database,
  user_id: Int,
  ttl_seconds: Int,
) -> Result(String, String) {
  create_token(db, user_id, Bootstrap, ttl_seconds)
}

pub fn create_refresh_token(
  db: Database,
  user_id: Int,
  ttl_seconds: Int,
) -> Result(String, String) {
  create_token(db, user_id, Refresh, ttl_seconds)
}

fn create_token(
  db: Database,
  user_id: Int,
  token_type: TokenType,
  ttl_seconds: Int,
) -> Result(String, String) {
  let raw = uuid.v4_string()
  let expires_at = birl.now() |> birl.add(duration.seconds(ttl_seconds))

  "INSERT INTO tokens (user_id, token_type, token_hash, expires_at) VALUES ($1, $2, $3, $4)"
  |> pog.query()
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.text(token_type_label(token_type)))
  |> pog.parameter(pog.text(hash_token(raw)))
  |> pog.parameter(pog.timestamp(timestamp_from_time(expires_at)))
  |> pog.execute(db)
  |> result.map(fn(_) { raw })
  |> result.map_error(fn(e) {
    logger.error_meta("Failed to create token", e)

    "Failed to create token"
  })
}

pub fn consume_bootstrap_token(
  db: Database,
  raw_token: String,
) -> Result(Int, String) {
  "UPDATE tokens
   SET used_at = NOW(), updated_at = NOW()
   WHERE token_type = 'bootstrap'
     AND token_hash = $1
     AND used_at IS NULL
     AND revoked_at IS NULL
     AND expires_at > $2
   RETURNING user_id"
  |> pog.query()
  |> pog.parameter(pog.text(hash_token(raw_token)))
  |> pog.parameter(pog.timestamp(timestamp_from_time(birl.now())))
  |> pog.returning(decode.at([0], decode.int))
  |> pog.execute(db)
  |> one()
  |> result.map_error(fn(_) { "Invalid or expired bootstrap token" })
}

pub fn rotate_refresh_token(
  db: Database,
  raw_token: String,
  ttl_seconds: Int,
) -> Result(#(Int, String), String) {
  let previous_hash = hash_token(raw_token)
  let next_raw = uuid.v4_string()
  let next_hash = hash_token(next_raw)
  let expires_at = birl.now() |> birl.add(duration.seconds(ttl_seconds))
  let now = timestamp_from_time(birl.now())

  transaction(db, fn(db) {
    use #(token_id, user_id) <- result.try(
      "SELECT id, user_id FROM tokens
       WHERE token_type = 'refresh'
         AND token_hash = $1
         AND used_at IS NULL
         AND revoked_at IS NULL
         AND expires_at > $2"
      |> pog.query()
      |> pog.parameter(pog.text(previous_hash))
      |> pog.parameter(pog.timestamp(now))
      |> pog.returning(token_user_decoder())
      |> pog.execute(db)
      |> one()
      |> result.map_error(fn(_) {
        DatabaseError("Invalid or expired refresh token")
      }),
    )

    use _ <- result.try(
      "UPDATE tokens
       SET used_at = NOW(), revoked_at = NOW(), replaced_by_token_hash = $1, updated_at = NOW()
       WHERE id = $2"
      |> pog.query()
      |> pog.parameter(pog.text(next_hash))
      |> pog.parameter(pog.int(token_id))
      |> pog.execute(db)
      |> result.map_error(QueryError),
    )

    "INSERT INTO tokens (user_id, token_type, token_hash, expires_at) VALUES ($1, 'refresh', $2, $3)"
    |> pog.query()
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(next_hash))
    |> pog.parameter(pog.timestamp(timestamp_from_time(expires_at)))
    |> pog.execute(db)
    |> result.map(fn(_) { #(user_id, next_raw) })
    |> result.map_error(QueryError)
  })
  |> result.map_error(fn(e) {
    logger.error_meta("Failed to rotate refresh token", e)

    "Invalid or expired refresh token"
  })
}
