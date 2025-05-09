import gleam/http/request.{type Request}
import gleam/http/response.{type Response}

pub type HttpProvider {
  HttpProvider(send: fn(Request(String)) -> Result(Response(String), String))
}

pub fn send(
  provider: HttpProvider,
  req: Request(String),
) -> Result(Response(String), String) {
  provider.send(req)
}
