import gleam/dict
import gleam/dynamic/decode
import gleam/result
import ids/uuid
import lti/jose

pub type Jwk {
  Jwk(kid: String, typ: String, alg: String, pem: String)
}

pub fn jwk_decoder() {
  use kid <- decode.field("kid", decode.string)
  use typ <- decode.optional_field("typ", "JWT", decode.string)
  use alg <- decode.optional_field("alg", "RS256", decode.string)
  use pem <- decode.field("pem", decode.string)

  decode.success(Jwk(kid, typ, alg, pem))
}

pub fn jwks_decoder() {
  use keys <- decode.field("keys", decode.list(jwk_decoder()))

  decode.success(keys)
}

pub fn to_map(jwk: Jwk) {
  let Jwk(pem: pem, ..) = jwk

  jose.from_pem(pem)
  |> jose.to_map()
}

pub fn from_map(kid: String, map: dict.Dict(String, String)) {
  let typ = dict.get(map, "typ") |> result.unwrap("JWT")
  let alg = dict.get(map, "alg") |> result.unwrap("RS256")
  let #(_, pem) = jose.to_pem(map)

  Ok(Jwk(kid, typ, alg, pem))
}

pub fn generate() {
  use kid <- result.try(uuid.generate_v4())

  let #(_, jwk_map) = jose.generate_key(jose.Rsa(2048)) |> jose.to_map()

  let typ = dict.get(jwk_map, "typ") |> result.unwrap("JWT")
  let alg = dict.get(jwk_map, "alg") |> result.unwrap("RS256")
  let #(_, pem) = jose.to_pem(jwk_map)

  Ok(Jwk(kid, typ, alg, pem))
}
