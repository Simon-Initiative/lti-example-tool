import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/result
import lti/lti_tool
import lti_tool_demo/app_context.{type AppContext}
import lti_tool_demo/session
import lti_tool_demo/utils/common.{try_with}
import wisp.{type Request, type Response, redirect}

pub fn oidc_login(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)

  use state <- try_with(result: dict.get(params, "state"), or_else: fn(_) {
    wisp.log_error("Missing state parameter")
    wisp.bad_request()
  })

  use redirect_url <- try_with(
    result: dict.get(params, "redirect_uri"),
    or_else: fn(_) {
      wisp.log_error("Missing redirect_uri parameter")
      wisp.bad_request()
    },
  )

  // Check if the state is valid
  case lti_tool.validate_oidc_login(params) {
    Ok(_) -> {
      // Set the state in the session
      let _ = session.put_session(req, app.session_config, "state", state)

      redirect(to: redirect_url)
    }
    Error(_) -> wisp.bad_request()
  }
}

fn all_params(
  req: Request,
  cb: fn(Dict(String, String)) -> Response,
) -> Response {
  use json <- wisp.require_json(req)

  // Combine query and body parameters into a single dictionary
  let query_params = wisp.get_query(req) |> dict.from_list()
  let body_params =
    decode.run(json, decode.dict(decode.string, decode.string))
    |> result.unwrap(dict.new())
  let params = dict.merge(query_params, body_params)

  cb(params)
}
