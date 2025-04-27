import gleam/dynamic/decode

pub type Jwk {
  Jwk(
    kid: String,
    kty: String,
    use_: String,
    typ: String,
    alg: String,
    n: String,
    e: String,
  )
}

pub fn jwk_decoder() {
  use kty <- decode.field("kty", decode.string)
  use e <- decode.field("e", decode.string)
  use n <- decode.field("n", decode.string)
  use kid <- decode.field("kid", decode.string)

  use alg <- decode.optional_field("alg", "RS256", decode.string)
  use use_ <- decode.optional_field("use", "sig", decode.string)
  use typ <- decode.optional_field("typ", "JWT", decode.string)

  decode.success(Jwk(
    kty: kty,
    e: e,
    n: n,
    kid: kid,
    alg: alg,
    use_: use_,
    typ: typ,
  ))
}

pub fn jwks_decoder() {
  use keys <- decode.field("keys", decode.list(jwk_decoder()))

  decode.success(keys)
}
