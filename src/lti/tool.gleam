import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/http/request
import gleam/http/response.{Response}
import gleam/httpc
import gleam/json
import gleam/list
import gleam/result
import gleam/uri.{query_to_string}
import gwt
import ids/uuid
import lti/data_provider.{type DataProvider}
import lti/jose.{JoseJwt}
import lti/providers/memory_provider/tables
import lti/registration.{type Registration}
import lti_tool_demo/utils/common.{try_with}
import lti_tool_demo/utils/logger

/// Initiates the OIDC login flow
pub fn oidc_login(
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

/// Validates the LTI launch
pub fn validate_launch(
  provider: DataProvider,
  params: Dict(String, String),
  session_state: String,
) {
  use id_token <- result.try(
    dict.get(params, "id_token") |> result.replace_error("Missing id_token"),
  )

  echo id_token

  // TODO: RE-ENABLE
  // use _state <- result.try(validate_oidc_state(params, session_state))
  use registration <- result.try(validate_launch_registration(
    provider,
    id_token,
  ))
  use jwt_body <- result.try(validate_id_token(
    id_token,
    registration.keyset_url,
  ))

  // TODO

  Ok(jwt_body)
}

fn validate_oidc_state(params, session_state) {
  use state <- result.try(
    dict.get(params, "state")
    |> result.replace_error("Missing state"),
  )

  case state == session_state {
    True -> Ok(state)
    False -> Error("Invalid state")
  }
}

fn validate_launch_registration(
  provider: DataProvider,
  id_token: String,
) -> Result(Registration, String) {
  use issuer, client_id <- peek_issuer_client_id(id_token)

  case data_provider.get_registration(provider, issuer, client_id) {
    Ok(#(_, registration)) -> Ok(registration)
    Error(_) -> {
      logger.error_meta(
        "Failed to get registration for issuer and client_id",
        #(issuer, client_id),
      )

      Error("Invalid registration")
    }
  }
}

fn peek_issuer_client_id(id_token, cb) {
  use issuer <- result.try(peek_claim(id_token, "iss", decode.string))
  use client_id <- result.try(peek_claim(id_token, "aud", decode.string))

  cb(issuer, client_id)
}

fn peek_claim(jwt_string: String, claim: String, decoder: Decoder(a)) {
  use unverified_token <- result.try(
    gwt.from_string(jwt_string) |> result.replace_error("Invalid JWT"),
  )

  gwt.get_payload_claim(unverified_token, claim, decoder)
  |> result.replace_error("Missing claim")
}

fn peek_header_claim(jwt_string, header: String, decoder: Decoder(a)) {
  use unverified_token <- result.try(
    gwt.from_string(jwt_string) |> result.replace_error("Invalid JWT"),
  )

  gwt.get_header_claim(unverified_token, header, decode.run(_, decoder))
  |> result.replace_error("Missing header")
}

fn validate_id_token(id_token, keyset_url) {
  use kid <- result.try(
    peek_header_claim(id_token, "kid", decode.string)
    |> result.replace_error("Missing kid"),
  )
  use jwk <- result.try(fetch_jwk(keyset_url, kid))

  case jose.verify(jwk, id_token) {
    #(True, JoseJwt(claims: claims), _) -> Ok(claims)

    _ -> {
      logger.error_meta("Failed to verify id_token", id_token)

      Error("Failed to verify id_token")
    }
  }
}

fn fetch_jwk(keyset_url, kid) {
  use req <- result.try(
    request.to(keyset_url) |> result.replace_error("Invalid keyset URL"),
  )

  let req =
    request.prepend_header(req, "accept", "application/vnd.hmrc.1.0+json")

  // Send the HTTP request to the server
  use resp <- result.try(
    httpc.send(req)
    |> result.replace_error("Failed to fetch keyset from " <> keyset_url),
  )

  case resp {
    Response(status: 200, body: body, ..) -> {
      // Parse the JSON response
      let keyset_decoder = {
        use keys <- decode.field(
          "keys",
          decode.list(decode.dict(decode.string, decode.string)),
        )

        decode.success(keys)
      }

      case json.parse(from: body, using: keyset_decoder) {
        Ok(keys) -> {
          // Extract the JWK from the JSON response
          list.find(keys, fn(key) { dict.get(key, "kid") == Ok(kid) })
          |> result.map_error(fn(_) {
            logger.error_meta("Failed to find JWK with kid " <> kid, keys)

            "Failed to find JWK with kid"
          })
        }
        Error(_) -> {
          logger.error_meta("Failed to parse keyset", #(keyset_url, body))

          Error("Failed to parse keyset")
        }
      }
    }
    Response(status: status, ..) -> {
      logger.error_meta("Failed to fetch keyset", #(status, keyset_url))

      Error("Failed to fetch keyset")
    }
  }
}
