import gleam/dict.{type Dict}
import gleam/result
import gleam/uri.{query_to_string}
import ids/uuid
import lti/data_provider.{type DataProvider}
import lti/providers/memory_provider/tables
import lti/registration.{type Registration}
import lti_tool_demo/utils/common.{try_with}

pub fn validate_oidc_login(
  provider: DataProvider,
  params: Dict(String, String),
) -> Result(#(String, String), String) {
  use _issuer <- result.try(validate_issuer_exists(params))
  use target_link_uri <- try_with(dict.get(params, "target_link_uri"), fn(_) {
    Error("Missing target_link_uri")
  })
  use login_hint <- result.try(validate_login_hint_exists(params))
  use registration <- result.try(result.replace_error(
    validate_registration(provider, params),
    "Invalid registration",
  ))
  use client_id <- result.try(validate_client_id_exists(params))

  let assert Ok(state) = uuid.generate_v4()
  let assert Ok(nonce) = data_provider.create_nonce(provider)

  let query_params = [
    #("scope", "openid"),
    #("response_type", "id_token"),
    #("response_mode", "form_post"),
    #("prompt", "none"),
    #("client_id", client_id),
    #("redirect_uri", target_link_uri),
    #("state", state),
    #("nonce", nonce.nonce),
    #("login_hint", login_hint),
  ]

  // pass back LTI message hint if given
  let query_params = case dict.get(params, "lti_message_hint") {
    Ok("") ->
      // if the hint is empty, we don't need to pass it back
      query_params
    Ok(lti_message_hint) -> [
      #("lti_message_hint", lti_message_hint),
      ..query_params
    ]
    Error(_) ->
      // if the hint is not present, we don't need to pass it back
      query_params
  }

  let redirect_url =
    registration.auth_endpoint <> "?" <> query_to_string(query_params)

  Ok(#(state, redirect_url))
}

fn validate_issuer_exists(
  params: Dict(String, String),
) -> Result(String, String) {
  case dict.get(params, "iss") {
    Ok(issuer) -> Ok(issuer)
    Error(_) -> Error("Missing issuer")
  }
}

fn validate_login_hint_exists(
  params: Dict(String, String),
) -> Result(String, String) {
  case dict.get(params, "login_hint") {
    Ok(login_hint) -> Ok(login_hint)
    Error(_) -> Error("Missing login hint")
  }
}

fn validate_registration(
  provider: DataProvider,
  params: Dict(String, String),
) -> Result(Registration, Nil) {
  use issuer <- result.try(dict.get(params, "iss"))
  use client_id <- result.try(dict.get(params, "client_id"))
  // use lti_deployment_id <- result.try(dict.get(params, "lti_deployment_id"))

  data_provider.get_registration(provider, issuer, client_id)
  |> result.map(tables.value)
}

fn validate_client_id_exists(
  params: Dict(String, String),
) -> Result(String, String) {
  case dict.get(params, "client_id") {
    Ok(client_id) -> Ok(client_id)
    Error(_) -> Error("Missing client id")
  }
}
