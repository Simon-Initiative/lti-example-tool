import lti_example_tool/app_context.{type AppContext}
import lti_example_tool_web/controllers/admin_auth_controller
import lti_example_tool_web/controllers/index_controller
import lti_example_tool_web/controllers/lti_controller
import lti_example_tool_web/controllers/registration_controller
import lti_example_tool_web/web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, app: AppContext) -> Response {
  use req <- web.middleware(req, app)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    [] -> index_controller.index(req)

    // This matches `/registrations` and any sub-paths like
    // `/registrations/123` or `/registrations/123/edit`.
    ["registrations", ..] -> registration_controller.resources(req, app)

    ["admin", "auth"] -> admin_auth_controller.sign_in(req, app)

    ["login"] -> lti_controller.oidc_login(req, app)

    ["launch"] -> lti_controller.validate_launch(req, app)

    ["deep-linking", "respond"] -> lti_controller.respond_deep_linking(req, app)

    ["app"] -> lti_controller.app(req, app)

    ["api", "auth", "token"] -> lti_controller.token(req, app)

    ["api", "me"] -> lti_controller.current_user(req, app)

    ["score"] -> lti_controller.send_score(req, app)

    ["memberships"] -> lti_controller.fetch_memberships(req, app)

    [".well-known", "jwks.json"] -> lti_controller.jwks(req, app)

    // This matches all other paths.
    _ -> wisp.not_found()
  }
}
