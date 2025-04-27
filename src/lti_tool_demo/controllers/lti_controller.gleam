import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import lti/tool
import lti_tool_demo/app_context.{type AppContext}
import lti_tool_demo/sessions.{session}
import lti_tool_demo/utils/common.{with}
import lti_tool_demo/utils/logger
import wisp.{type Request, type Response, redirect}

pub fn oidc_login(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)

  case tool.oidc_login(app.lti_data_provider, params) {
    Ok(#(state, redirect_url)) -> {
      // Set the state in the session
      let assert Ok(_) =
        sessions.put_session(req, app.session_config, "state", state)

      redirect(to: redirect_url)
    }
    Error(e) ->
      wisp.bad_request()
      |> wisp.html_body(string_tree.from_string(
        "<h1>LTI Tool Demo - OIDC Login Failed</h1>"
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
  // use json <- wisp.require_json(req)
  use formdata <- wisp.require_form(req)

  // Combine query and body parameters into a single dictionary
  let query_params = wisp.get_query(req) |> dict.from_list()
  // let body_params =
  //   decode.run(json, decode.dict(decode.string, decode.string))
  //   |> result.unwrap(dict.new())
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

  // use session_state <- session(req, app.session_config, "state")
  // use session_state <- with(session_state, fn() {
  //   logger.error("Session state not found")

  //   wisp.bad_request()
  // })
  // TODO: FIX
  let session_state = ""

  // Validate the launch
  case tool.validate_launch(app.lti_data_provider, params, session_state) {
    Ok(claims) -> {
      let html =
        string_tree.from_string(
          "<h1>LTI Tool Demo - Launch Successful</h1>"
          <> "<p>"
          <> string.inspect(claims)
          <> "</p>",
        )

      wisp.ok()
      |> wisp.html_body(html)
    }
    Error(e) -> {
      logger.error_meta("Invalid launch", e)

      wisp.bad_request()
      |> wisp.html_body(string_tree.from_string(
        "<h1>LTI Tool Demo - Launch Failed</h1>"
        <> "<p>"
        <> string.inspect(e)
        <> "</p>",
      ))
    }
  }
}

pub fn jwks(req: Request, app: AppContext) -> Response {
  // use <- wisp.require_method(req, Get)

  // // Get the public keys from the data provider
  // let assert Ok(keys) = lti_tool.get_jwks(app.lti_data_provider)

  // // Convert the keys to a JSON response
  // let json = decode.encode(keys)

  // wisp.ok()
  // |> wisp.json_body(json)

  todo
}
