import gleam/dict
import gleam/dynamic/decode
import gleam/result
import ids/uuid
import lti/jose

pub type Jwk {
  Jwk(kid: String, kty: String, alg: String, use_: String, n: String, e: String)
}

pub fn jwk_decoder() {
  use kid <- decode.field("kid", decode.string)
  use kty <- decode.field("kty", decode.string)
  use alg <- decode.optional_field("alg", "RS256", decode.string)
  use use_ <- decode.optional_field("use", "sig", decode.string)
  use e <- decode.field("e", decode.string)
  use n <- decode.field("n", decode.string)

  decode.success(Jwk(kty: kty, e: e, n: n, kid: kid, alg: alg, use_: use_))
}

pub fn jwks_decoder() {
  use keys <- decode.field("keys", decode.list(jwk_decoder()))

  decode.success(keys)
}

pub fn to_map(jwk: Jwk) {
  let Jwk(kid, kty, alg, use_, n, e) = jwk

  dict.from_list([
    #("kid", kid),
    #("kty", kty),
    #("use", use_),
    #("alg", alg),
    #("n", n),
    #("e", e),
  ])
}

pub fn from_map(kid: String, map: dict.Dict(String, String)) {
  use kty <- result.try(
    dict.get(map, "kty") |> result.replace_error("Missing kty"),
  )
  let alg = dict.get(map, "alg") |> result.unwrap("RS256")
  let use_ = dict.get(map, "use") |> result.unwrap("sig")
  use n <- result.try(dict.get(map, "n") |> result.replace_error("Missing n"))
  use e <- result.try(dict.get(map, "e") |> result.replace_error("Missing e"))

  Ok(Jwk(kid: kid, kty: kty, alg: alg, use_: use_, n: n, e: e))
}

pub fn generate() {
  use kid <- result.try(uuid.generate_v4())

  let #(_, jwk_map) = jose.generate_key(jose.Rsa(2048)) |> jose.to_map()

  from_map(kid, jwk_map)
}
