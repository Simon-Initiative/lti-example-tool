import birl
import birl/duration
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/result
import lightbulb/jose
import lightbulb/jwk
import lti_example_tool/database.{type Database}
import lti_example_tool/jwks
import youid/uuid

const issuer = "lti_example_tool"

const audience = "lti_example_tool_client_api"

pub fn issue_access_token(
  db: Database,
  user_id: Int,
  ttl_seconds: Int,
) -> Result(String, String) {
  use active_jwk <- result.try(
    jwks.get_active_jwk(db)
    |> result.map(fn(record) { record.data })
    |> result.replace_error("Failed to get active JWK"),
  )

  let #(_, jwk_map) = active_jwk |> jwk.to_map()
  let now = birl.now() |> birl.to_unix()
  let exp =
    birl.now() |> birl.add(duration.seconds(ttl_seconds)) |> birl.to_unix()
  let jti = uuid.v4_string()

  let claims =
    dict.from_list([
      #("iss", dynamic.string(issuer)),
      #("aud", dynamic.string(audience)),
      #("sub", dynamic.string(int.to_string(user_id))),
      #("uid", dynamic.int(user_id)),
      #("iat", dynamic.int(now)),
      #("exp", dynamic.int(exp)),
      #("jti", dynamic.string(jti)),
      #("typ", dynamic.string("access")),
    ])

  let jws =
    dict.from_list([
      #("alg", "RS256"),
      #("typ", "JWT"),
      #("kid", active_jwk.kid),
    ])

  let #(_, signed) = jose.sign_with_jws(jwk_map, jws, claims)
  let #(_, compact) = jose.compact(signed)

  Ok(compact)
}

pub fn verify_access_token(db: Database, token: String) -> Result(Int, String) {
  use kid <- result.try(extract_kid(token))

  use key <- result.try(
    jwks.get(db, kid)
    |> result.map(fn(record) { record.data })
    |> result.replace_error("Unknown key id"),
  )

  let #(_, jwk_map) = key |> jwk.to_map()
  let #(valid, jwt, _) = jose.verify(jose.from_map(jwk_map), token)

  case valid {
    False -> Error("Invalid access token signature")
    True -> validate_claims(jwt)
  }
}

fn extract_kid(token: String) -> Result(String, String) {
  let jose.JoseJws(headers:, ..) = jose.peek_protected(token)

  use kid <- result.try(
    dict.get(headers, "kid")
    |> result.replace_error("Missing key id")
    |> result.try(fn(value) {
      decode.run(value, decode.string) |> result.replace_error("Invalid key id")
    }),
  )

  Ok(kid)
}

fn validate_claims(jwt: jose.JoseJwt) -> Result(Int, String) {
  let jose.JoseJwt(claims:) = jwt
  let now = birl.now() |> birl.to_unix()

  use uid <- result.try(required_int_claim(claims, "uid"))
  use exp <- result.try(required_int_claim(claims, "exp"))
  use token_issuer <- result.try(required_string_claim(claims, "iss"))
  use token_audience <- result.try(required_string_claim(claims, "aud"))
  use token_type <- result.try(required_string_claim(claims, "typ"))

  case token_issuer == issuer {
    False -> Error("Invalid access token issuer")
    True ->
      case token_audience == audience {
        False -> Error("Invalid access token audience")
        True ->
          case token_type == "access" {
            False -> Error("Invalid access token type")
            True ->
              case exp > now {
                True -> Ok(uid)
                False -> Error("Access token expired")
              }
          }
      }
  }
}

fn required_string_claim(
  claims: dict.Dict(String, dynamic.Dynamic),
  key: String,
) -> Result(String, String) {
  dict.get(claims, key)
  |> result.replace_error("Missing claim: " <> key)
  |> result.try(fn(value) {
    decode.run(value, decode.string)
    |> result.replace_error("Invalid claim: " <> key)
  })
}

fn required_int_claim(
  claims: dict.Dict(String, dynamic.Dynamic),
  key: String,
) -> Result(Int, String) {
  dict.get(claims, key)
  |> result.replace_error("Missing claim: " <> key)
  |> result.try(fn(value) {
    decode.run(value, decode.int)
    |> result.replace_error("Invalid claim: " <> key)
  })
}
