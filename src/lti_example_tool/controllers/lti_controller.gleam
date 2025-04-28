import gleam/dict.{type Dict}
import gleam/http
import gleam/http/cookie
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/string_tree
import lti/tool
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/cookies.{require_cookie, set_cookie}
import lti_example_tool/utils/logger
import wisp.{type Request, type Response, redirect}

pub fn oidc_login(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)

  case tool.oidc_login(app.lti_data_provider, params) {
    Ok(#(state, redirect_url)) -> {
      use <- set_cookie(
        "state",
        state,
        cookie.Attributes(
          ..cookie.defaults(http.Https),
          same_site: Some(cookie.None),
          max_age: option.Some(60 * 60 * 24),
        ),
      )

      redirect(to: redirect_url)
    }
    Error(e) ->
      wisp.bad_request()
      |> wisp.html_body(string_tree.from_string(
        "<h1>LTI Example Tool - OIDC Login Failed</h1>"
        <> "<p>"
        <> string.inspect(e)
        <> "</p>",
      ))
  }
}

fn all_params(
  req: Request,
  cb: fn(Dict(String, String)) -> Response,
) -> Response {
  use formdata <- wisp.require_form(req)

  // Combine query and body parameters into a single dictionary
  let query_params = wisp.get_query(req) |> dict.from_list()

  let body_params =
    formdata.values
    |> list.fold(dict.new(), fn(acc, field) {
      let #(key, value) = field
      dict.insert(acc, key, value)
    })

  let params = dict.merge(query_params, body_params)

  cb(params)
}

pub fn validate_launch(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)
  use session_state <- require_cookie(req, "state", or_else: fn() {
    logger.error("Required 'state' cookie not found")

    render_error("Required 'state' cookie not found")
  })

  case tool.validate_launch(app.lti_data_provider, params, session_state) {
    Ok(claims) -> {
      let html =
        string_tree.from_string(
          "<h1>LTI Example Tool - Launch Successful</h1>"
          <> "<p>"
          <> string.inspect(claims)
          <> "</p>",
        )

      wisp.ok()
      |> wisp.html_body(html)
    }
    Error(e) -> {
      logger.error_meta("Invalid launch", e)

      render_error("Invalid launch: " <> string.inspect(e))
    }
  }
}

fn render_error(reason: String) -> Response {
  wisp.bad_request()
  |> wisp.html_body(string_tree.from_string(
    "<h1>Something went wrong</h1>" <> "<p>Reason: " <> reason <> "</p>",
  ))
}
