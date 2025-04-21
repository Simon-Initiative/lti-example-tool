import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/crypto
import gleam/http/response.{type Response}
import gleam/option.{type Option, None, Some}
import gleam/string
import mist.{type ResponseData}

pub fn mist_response(response: Response(BytesTree)) -> Response(ResponseData) {
  response.new(response.status)
  |> response.set_body(mist.Bytes(response.body))
}

/// Generate a random string of the given length
pub fn random_string(length: Int) -> String {
  crypto.strong_random_bytes(length)
  |> bit_array.base64_url_encode(False)
  |> string.slice(0, length)
}

pub fn with(
  some optional: Option(a),
  or_else recover: fn() -> b,
  do f: fn(a) -> b,
) -> b {
  case optional {
    Some(value) -> f(value)
    None -> recover()
  }
}

pub fn try_with(
  result required: Result(a, b),
  or_else recover: fn(b) -> c,
  do f: fn(a) -> c,
) -> c {
  case required {
    Ok(value) -> f(value)
    Error(error) -> recover(error)
  }
}
