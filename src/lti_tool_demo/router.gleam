import gleam/http.{Get, Post}
import gleam/int
import gleam/string
import gleam/string_tree
import lti_tool_demo/app_context.{type AppContext}
import lti_tool_demo/controllers/lti_controller
import lti_tool_demo/platforms
import lti_tool_demo/utils/common.{try_with}
import lti_tool_demo/web
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
    ["platforms"] -> platforms(req, app)

    // This matches `/comments/:id`.
    // The `id` segment is bound to a variable and passed to the handler.
    ["platforms", id] -> show_platform(req, app, id)

    ["login"] -> lti_controller.oidc_login(req, app)
    ["keys"] -> lti_controller.jwks(req, app)

    ["launch"] -> launch(req)

    // TODO: REMOVE
    ["lti", "login"] -> lti_controller.oidc_login(req, app)
    ["lti", "launch"] -> launch(req)

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
      "LTI Tool Demo"
      <> "\n"
      <> "This is an example web application that demonstrates how to build an LTI tool.",
    )

  wisp.ok()
  |> wisp.html_body(html)
}

fn launch(req: Request) -> Response {
  // The launch page can only be accessed via GET requests, so this middleware is
  // used to return a 405: Method Not Allowed response for all other methods.
  // use <- wisp.require_method(req, Get)

  let html = string_tree.from_string("LTI Tool Demo" <> "\n" <> "Launch")

  wisp.ok()
  |> wisp.html_body(html)
}

fn platforms(req: Request, app: AppContext) -> Response {
  // This handler for `/platforms` can respond to both GET and POST requests,
  // so we pattern match on the method here.
  case req.method {
    Get -> list_platforms(app)
    Post -> create_platform(req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_platforms(app: AppContext) -> Response {
  let assert Ok(platforms) = platforms.all(app.db)

  let html =
    string_tree.from_string("Platforms" <> "\n" <> string.inspect(platforms))

  wisp.ok()
  |> wisp.html_body(html)
}

fn create_platform(_req: Request) -> Response {
  todo
}

fn show_platform(req: Request, app: AppContext, id: String) -> Response {
  use <- wisp.require_method(req, Get)

  use id <- try_with(int.parse(id), or_else: fn(_) {
    wisp.log_error("Invalid platform ID")
    wisp.bad_request()
  })

  let assert Ok(platforms) = platforms.get(app.db, id)

  let html =
    string_tree.from_string("Platforms" <> "\n" <> string.inspect(platforms))

  wisp.ok()
  |> wisp.html_body(html)
}
