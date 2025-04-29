import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/http
import gleam/http/cookie
import gleam/list
import gleam/option.{Some}
import gleam/string
import lti/tool
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/cookies.{require_cookie, set_cookie}
import lti_example_tool/html.{render_error_page, render_page} as _
import lti_example_tool/html/tables.{Column}
import lti_example_tool/utils/logger
import lustre/attribute.{class}
import lustre/element/html.{div, span, text}
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
    Error(error) -> render_error_page("OIDC login failed: " <> error)
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

    render_error_page("Required 'state' cookie not found")
  })

  case tool.validate_launch(app.lti_data_provider, params, session_state) {
    Ok(claims) -> {
      render_page("Launch Successful", [
        div([class("container")], [
          tables.table(
            [],
            [
              Column("Claim", fn(record: #(String, Dynamic)) {
                let #(claim, _value) = record
                span([class("font-semibold")], [text(claim)])
              }),
              Column("Value", fn(record: #(String, Dynamic)) {
                let #(_key, value) = record
                text(string.inspect(value))
              }),
            ],
            dict.to_list(claims),
          ),
        ]),
      ])
    }
    Error(e) -> {
      logger.error_meta("Invalid launch", e)

      render_error_page("Invalid launch: " <> string.inspect(e))
    }
  }
}
