import gleam/http.{Get, Post}
import gleam/int
import gleam/string
import gleam/string_tree
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/controllers/lti_controller
import lti_example_tool/controllers/platform_controller
import lti_example_tool/platforms
import lti_example_tool/utils/common.{try_with}
import lti_example_tool/web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, app: AppContext) -> Response {
  use req <- web.middleware(req, app)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    [] -> home(req)

    // This matches `/comments`.
    ["platforms", ..] -> platform_controller.resources(req, app)

    ["login"] -> lti_controller.oidc_login(req, app)

    ["launch"] -> lti_controller.validate_launch(req, app)

    // TODO: REMOVE
    ["lti", "login"] -> lti_controller.oidc_login(req, app)
    ["lti", "launch"] -> lti_controller.validate_launch(req, app)

    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn home(req: Request) -> Response {
  // The home page can only be accessed via GET requests, so this middleware is
  // used to return a 405: Method Not Allowed response for all other methods.
  use <- wisp.require_method(req, Get)

  let html =
    string_tree.from_string(
      "LTI Example Tool"
      <> "\n"
      <> "This is an example web application that demonstrates how to build an LTI tool.",
    )

  wisp.ok()
  |> wisp.html_body(html)
}
