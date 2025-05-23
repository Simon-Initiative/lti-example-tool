/// Wisp doesn't have fine grain control over cookies required to allow cookies
/// to be passed across domains. This module provides a workaround way to set
/// and read cookies with the correct attributes.
import gleam/http/cookie
import gleam/http/request
import gleam/http/response
import gleam/list
import wisp.{type Request, type Response}

pub fn set_cookie(
  name: String,
  value: String,
  attributes: cookie.Attributes,
  cb: fn() -> Response,
) -> Response {
  cb()
  |> response.set_cookie(name, value, attributes)
}

pub fn require_cookie(
  req: Request,
  cookie_name: String,
  or_else bail: fn() -> Response,
  cb cb: fn(String) -> Response,
) -> Response {
  case get_cookie(req, cookie_name) {
    Ok(cookie) -> cb(cookie)
    Error(_) -> bail()
  }
}

pub fn get_cookie(req: Request, name name: String) -> Result(String, Nil) {
  req
  |> request.get_cookies
  |> list.key_find(name)
}
