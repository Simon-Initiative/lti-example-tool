import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}

pub type JoseJwk =
  Dict(String, String)

pub type Claims =
  Dict(String, Dynamic)

pub type JoseJwt {
  JoseJwt(claims: Claims)
}

pub type JoseJwsAlg

pub type JoseJws {
  JoseJws(alg: JoseJwsAlg, payload: String, headers: Claims)
}

@external(erlang, "jose_jwt", "sign")
pub fn sign(
  jwk: Dict(String, String),
  token: Dict(String, String),
) -> #(JoseJws, Dict(String, String))

@external(erlang, "jose_jwt", "sign")
pub fn sign_with_jws(
  jwk: Dict(String, String),
  jws: Dict(String, String),
  token: Dict(String, Dynamic),
) -> #(JoseJws, Dict(String, String))

@external(erlang, "jose_jws", "compact")
pub fn compact(signed: Dict(String, String)) -> #(Dict(String, String), String)

@external(erlang, "jose_jwt", "verify")
pub fn verify(jwk: JoseJwk, signed_token: String) -> #(Bool, JoseJwt, JoseJws)

@external(erlang, "jose_jwt", "peek")
pub fn peek(jwt_string: String) -> JoseJwt

@external(erlang, "jose_jwt", "peek_protected")
pub fn peek_protected(jwt_string: String) -> JoseJws

@external(erlang, "jose_jwt", "to_binary")
pub fn to_binary(jwt: JoseJwt) -> String

@external(erlang, "jose_jwt", "from_binary")
pub fn from_binary(jwt_string: String) -> JoseJwt

/// JWK
@external(erlang, "jose_jwk", "from_map")
pub fn from_map(map: Dict(String, String)) -> JoseJwk

@external(erlang, "jose_jwk", "from_pem")
pub fn from_pem(pem: String) -> JoseJwk

@external(erlang, "jose_jwk", "to_public")
pub fn to_public(jwk: JoseJwk) -> JoseJwk

/// This function will take a JoseJwk and convert it to a PEM string.
/// Returns a tuple of the form #(params, pem) where params is a map of
/// parameters and pem is the PEM string. The params map should contain
/// the Kty (the key type).
@external(erlang, "jose_jwk", "to_pem")
pub fn to_pem(jwk: JoseJwk) -> #(Dict(String, Dynamic), String)

@external(erlang, "jose_jwk", "to_map")
pub fn to_map(jwk: JoseJwk) -> #(Dict(String, Dynamic), Dict(String, String))

pub type GenerateKeyParams {
  Rsa(modulus_size: Int)
}

@external(erlang, "jose_jwk", "generate_key")
pub fn generate_key(params: GenerateKeyParams) -> JoseJwk

/// UTILITY FUNCTIONS
@external(erlang, "erlang", "display")
pub fn erlang_display(term: a) -> Bool
