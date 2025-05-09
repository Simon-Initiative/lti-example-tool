import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/result

/// Creates a JSON decoder compatible with Gleam's decode module.
pub fn json_decoder(
  deocder: decode.Decoder(a),
) -> fn(Dynamic) -> Result(a, List(dynamic.DecodeError)) {
  fn(json: Dynamic) -> Result(a, List(dynamic.DecodeError)) {
    decode.run(json, deocder)
    |> result.map_error(map_decode_errors_to_dynamic_errors)
  }
}

fn map_decode_errors_to_dynamic_errors(
  errors: List(decode.DecodeError),
) -> List(dynamic.DecodeError) {
  list.map(errors, fn(error) {
    let decode.DecodeError(expected, found, path) = error

    dynamic.DecodeError(expected, found, path)
  })
}
