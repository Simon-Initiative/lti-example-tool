import gleam/http.{Get}
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/controllers/lti_controller
import lti_example_tool/controllers/registration_controller
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
    ["registrations", ..] -> registration_controller.resources(req, app)

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
  use <- wisp.require_method(req, Get)

  wisp.redirect("/registrations")
}
