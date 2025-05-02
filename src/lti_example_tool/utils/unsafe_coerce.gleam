import gleam/dynamic.{type Dynamic}

@external(erlang, "gleam_stdlib", "identity")
pub fn unsafe_coerce(a: Dynamic) -> anything
