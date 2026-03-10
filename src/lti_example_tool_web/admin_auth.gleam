import gleam/crypto
import gleam/http/request
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri
import lti_example_tool/admin_auth as core_admin_auth
import wisp

pub const session_cookie_name = "admin_session"

pub const session_ttl_seconds = 43_200

pub fn require_admin(
  req: wisp.Request,
  auth: core_admin_auth.AdminAuth,
  next: fn() -> wisp.Response,
) -> wisp.Response {
  case authenticated(req, auth) {
    True -> next()
    False -> wisp.redirect(sign_in_redirect(req))
  }
}

pub fn authenticated(req: wisp.Request, auth: core_admin_auth.AdminAuth) -> Bool {
  case
    core_admin_auth.session_value(auth),
    wisp.get_cookie(req, session_cookie_name, wisp.Signed)
  {
    Ok(session_value), Ok(cookie_value) ->
      crypto.secure_compare(<<cookie_value:utf8>>, <<session_value:utf8>>)

    _, _ -> False
  }
}

pub fn sign_in_redirect(req: wisp.Request) -> String {
  "/admin/auth?" <> uri.query_to_string([#("return_to", requested_path(req))])
}

pub fn return_to(req: wisp.Request) -> String {
  req
  |> request.get_query
  |> result.unwrap([])
  |> list.key_find("return_to")
  |> result.unwrap("/registrations")
  |> sanitize_return_to
}

pub fn sanitize_return_to(value: String) -> String {
  case string.starts_with(value, "/") && !string.starts_with(value, "//") {
    True -> value
    False -> "/registrations"
  }
}

pub fn configuration_error() -> String {
  "Registration admin access is unavailable because ADMIN_PASSWORD is not configured."
}

fn requested_path(req: wisp.Request) -> String {
  case req.query {
    Some(query) -> req.path <> "?" <> query
    None -> req.path
  }
}
