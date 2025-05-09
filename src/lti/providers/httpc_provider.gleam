import gleam/httpc
import gleam/result
import gleam/string
import lti/providers/http_provider.{HttpProvider}

pub fn http_provider() {
  HttpProvider(send: fn(req) {
    httpc.send(req)
    |> result.map_error(fn(e) {
      "Error sending HTTP request: " <> string.inspect(e)
    })
  })
}
