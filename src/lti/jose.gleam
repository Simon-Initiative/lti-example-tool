import gleam/dict.{type Dict}

pub type JoseJwk =
  Dict(String, String)

pub type JoseJwt {
  JoseJwt(claims: Dict(String, String))
}

pub type JoseJwsAlg

pub type JoseJws {
  JoseJws(alg: JoseJwsAlg, payload: String, headers: Dict(String, String))
}

@external(erlang, "jose_jwt", "verify")
pub fn verify(jwk: JoseJwk, signed_token: String) -> #(Bool, JoseJwt, JoseJws)

/// UTILITY FUNCTIONS
@external(erlang, "erlang", "display")
pub fn erlang_display(term: a) -> Bool
