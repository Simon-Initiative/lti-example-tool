import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import gleam/string
import lti_example_tool/admin_auth as core_admin_auth
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool_web/admin_auth as admin_auth_web
import lti_example_tool_web/html.{render_html, render_html_status}
import lti_example_tool_web/html/admin_auth_html
import lti_example_tool_web/html/components/page.{error_page}
import wisp.{type FormData, type Request, type Response}

pub fn sign_in(req: Request, app: AppContext) -> Response {
  case core_admin_auth.is_configured(app.admin_auth) {
    False ->
      render_html_status(error_page(admin_auth_web.configuration_error()), 500)

    True ->
      case req.method {
        Get -> show_sign_in(req, app)
        Post -> create_session(req, app)
        _ -> wisp.method_not_allowed([Get, Post])
      }
  }
}

fn show_sign_in(req: Request, app: AppContext) -> Response {
  let return_to = admin_auth_web.return_to(req)

  case admin_auth_web.authenticated(req, app.admin_auth) {
    True -> wisp.redirect(return_to)
    False -> render_html(admin_auth_html.sign_in(return_to, ""))
  }
}

fn create_session(req: Request, app: AppContext) -> Response {
  use form <- wisp.require_form(req)

  let password = form_value(form, "password")
  let return_to =
    form_value(form, "return_to") |> admin_auth_web.sanitize_return_to

  case core_admin_auth.verify_password(app.admin_auth, password) {
    True -> {
      let assert Ok(session_value) =
        core_admin_auth.session_value(app.admin_auth)

      wisp.redirect(return_to)
      |> wisp.set_cookie(
        req,
        admin_auth_web.session_cookie_name,
        session_value,
        wisp.Signed,
        admin_auth_web.session_ttl_seconds,
      )
    }

    False ->
      render_html_status(
        admin_auth_html.sign_in(return_to, "Incorrect password."),
        401,
      )
  }
}

fn form_value(form: FormData, name: String) -> String {
  form.values
  |> list.key_find(name)
  |> result.unwrap("")
  |> string.trim
}
