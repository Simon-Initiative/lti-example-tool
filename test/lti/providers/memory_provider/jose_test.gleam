import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/string
import gleeunit/should
import lti/jose

pub fn generate_key_test() {
  let jose_jwk = jose.generate_key(jose.Rsa(2048))

  let #(params, pem) = jose.to_pem(jose_jwk)

  params
  |> dict.is_empty()
  |> should.be_false()

  string.is_empty(pem)
  |> should.be_false()
}

pub fn sign_test() {
  let #(_, jwk) = jose.generate_key(jose.Rsa(2048)) |> jose.to_map()

  let jwt =
    dict.from_list([#("iss", "test"), #("aud", "test"), #("sub", "test")])

  let #(_jose_jws, jose_jwt) = jose.sign(jwk, jwt)

  let assert Ok(payload) = dict.get(jose_jwt, "payload")
  let assert Ok(signature) = dict.get(jose_jwt, "signature")
  let assert Ok(protected) = dict.get(jose_jwt, "protected")

  payload
  |> string.is_empty()
  |> should.be_false()

  signature
  |> string.is_empty()
  |> should.be_false()

  protected
  |> string.is_empty()
  |> should.be_false()
}

pub fn sign_with_jws_compact_test() {
  let #(_, jwk) = jose.generate_key(jose.Rsa(2048)) |> jose.to_map()

  let jws =
    dict.from_list([#("alg", "RS256"), #("typ", "JWT"), #("kid", "test")])

  let jwt =
    dict.from_list([
      #("iss", dynamic.from("test")),
      #("aud", dynamic.from("test")),
      #("sub", dynamic.from("test")),
    ])

  let #(_jose_jws, jose_jwt) = jose.sign_with_jws(jwk, jws, jwt)

  let assert Ok(payload) = dict.get(jose_jwt, "payload")
  let assert Ok(signature) = dict.get(jose_jwt, "signature")
  let assert Ok(protected) = dict.get(jose_jwt, "protected")

  payload
  |> string.is_empty()
  |> should.be_false()

  signature
  |> string.is_empty()
  |> should.be_false()

  protected
  |> string.is_empty()
  |> should.be_false()

  let #(_, compact_signed) = jose.compact(jose_jwt)

  compact_signed
  |> string.is_empty()
  |> should.be_false()

  let #(verified, verified_jwt, _verified_jws) =
    jose.verify(jwk, compact_signed)

  verified
  |> should.be_true()

  let assert Ok(aud) = dict.get(verified_jwt.claims, "aud")
  let assert Ok(iss) = dict.get(verified_jwt.claims, "iss")
  let assert Ok(sub) = dict.get(verified_jwt.claims, "sub")

  aud
  |> unsafe_coerce()
  |> should.equal("test")

  iss
  |> unsafe_coerce()
  |> should.equal("test")

  sub
  |> unsafe_coerce()
  |> should.equal("test")
}

@external(erlang, "gleam_stdlib", "identity")
fn unsafe_coerce(a: Dynamic) -> anything
