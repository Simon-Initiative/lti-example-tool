import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}

pub type JoseJwk =
  Dict(String, String)

pub type JoseJwt {
  JoseJwt(claims: Dict(String, Dynamic))
}

pub type JoseJwsAlg

pub type JoseJws {
  JoseJws(alg: JoseJwsAlg, payload: String, headers: Dict(String, Dynamic))
}

@external(erlang, "jose_jwt", "verify")
pub fn verify(jwk: JoseJwk, signed_token: String) -> #(Bool, JoseJwt, JoseJws)

@external(erlang, "jose_jwt", "peek")
pub fn peek(jwt_string: String) -> JoseJwt

@external(erlang, "jose_jwt", "peek_protected")
pub fn peek_protected(jwt_string: String) -> JoseJws

/// UTILITY FUNCTIONS
@external(erlang, "erlang", "display")
pub fn erlang_display(term: a) -> Bool
