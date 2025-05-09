import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import lti/providers/http_provider.{HttpProvider}

pub fn http_provider(
  callback: fn(Request(String)) -> Result(Response(String), String),
) {
  HttpProvider(send: callback)
}
