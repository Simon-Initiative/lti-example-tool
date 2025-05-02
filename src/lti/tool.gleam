import birl
import birl/duration
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/http/request
import gleam/http/response.{Response}
import gleam/httpc
import gleam/json
import gleam/list
import gleam/order.{Gt, Lt}
import gleam/result
import gleam/uri.{query_to_string}
import ids/uuid
import lti/data_provider.{type DataProvider}
import lti/jose.{type Claims, JoseJws, JoseJwt}
import lti/registration.{type Registration}
import lti_example_tool/utils/common.{try_with}
import lti_example_tool/utils/logger

const deployment_id_claim = "https://purl.imsglobal.org/spec/lti/claim/deployment_id"

const message_type_claim = "https://purl.imsglobal.org/spec/lti/claim/message_type"

const lti_message_hint_claim = "lti_message_hint"

/// Initiates the OIDC login flow. Returns the state and redirect URL.
/// The state is a random UUID that is used to verify the response from the OIDC provider.
/// The redirect URL is the URL to which the user should be redirected to complete the login flow.
pub fn oidc_login(
  provider: DataProvider,
  params: Dict(String, String),
) -> Result(#(String, String), String) {
  use _params <- result.try(validate_issuer_exists(params))
  use target_link_uri <- try_with(dict.get(params, "target_link_uri"), fn(_) {
    Error("Missing target_link_uri")
  })
  use login_hint <- result.try(validate_login_hint_exists(params))
  use registration <- result.try(validate_registration(provider, params))
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
  let query_params = case dict.get(params, lti_message_hint_claim) {
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
) -> Result(Dict(String, String), String) {
  case dict.get(params, "iss") {
    Ok(_issuer) -> Ok(params)
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
) -> Result(Registration, String) {
  use issuer <- result.try(
    dict.get(params, "iss") |> result.replace_error("Missing issuer"),
  )
  use client_id <- result.try(
    dict.get(params, "client_id") |> result.replace_error("Missing client_id"),
  )

  data_provider.get_registration(provider, issuer, client_id)
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
) -> Result(Claims, String) {
  use id_token <- result.try(
    dict.get(params, "id_token") |> result.replace_error("Missing id_token"),
  )
  use _state <- result.try(validate_oidc_state(params, session_state))
  use registration <- result.try(peek_validate_registration(id_token, provider))
  use claims <- result.try(verify_token(id_token, registration.keyset_url))
  use _claims <- result.try(validate_deployment(
    claims,
    provider,
    registration.issuer,
    registration.client_id,
  ))
  use _claims <- result.try(validate_timestamps(claims))
  use _claims <- result.try(validate_nonce(claims, provider))
  use _claims <- result.try(validate_message(claims))

  Ok(claims)
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

fn peek_validate_registration(
  id_token: String,
  provider: DataProvider,
) -> Result(Registration, String) {
  use #(issuer, client_id) <- result.try(peek_issuer_client_id(id_token))

  data_provider.get_registration(provider, issuer, client_id)
}

fn peek_issuer_client_id(id_token) {
  use issuer <- result.try(peek_claim(id_token, "iss", decode.string))
  use client_id <- result.try(peek_claim(id_token, "aud", decode.string))

  Ok(#(issuer, client_id))
}

fn peek_claim(jwt_string: String, claim: String, decoder: Decoder(a)) {
  case jose.peek(jwt_string) {
    JoseJwt(claims: claims) -> {
      case dict.get(claims, claim) {
        Ok(value) ->
          decode.run(value, decoder) |> result.replace_error("Invalid claim")
        Error(_) -> Error("Missing claim")
      }
    }
  }
}

fn peek_header_claim(jwt_string, header: String, decoder: Decoder(a)) {
  case jose.peek_protected(jwt_string) {
    JoseJws(headers: headers, ..) -> {
      case dict.get(headers, header) {
        Ok(value) ->
          decode.run(value, decoder) |> result.replace_error("Invalid header")
        Error(_) -> Error("Missing header")
      }
    }
  }
}

fn verify_token(id_token, keyset_url) {
  use kid <- result.try(
    peek_header_claim(id_token, "kid", decode.string)
    |> result.replace_error("Missing kid"),
  )
  use jwk <- result.try(fetch_jwk(keyset_url, kid))

  case jose.verify(jose.from_map(jwk), id_token) {
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

fn validate_deployment(
  claims: Claims,
  provider: DataProvider,
  issuer: String,
  client_id: String,
) {
  use deployment_id <- result.try(get_claim(
    claims,
    deployment_id_claim,
    decode.string,
  ))

  data_provider.get_deployment(provider, issuer, client_id, deployment_id)
}

fn validate_timestamps(claims: Claims) {
  use exp <- result.try(
    get_claim(claims, "exp", decode.int)
    |> result.map(birl.from_unix),
  )
  use iat <- result.try(
    get_claim(claims, "iat", decode.int) |> result.map(birl.from_unix),
  )

  let now = birl.now()
  let buffer_sec = 2
  let a_few_seconds_ago = birl.subtract(now, duration.seconds(buffer_sec))
  let a_few_seconds_later = birl.add(now, duration.seconds(buffer_sec))

  use <- bool.guard(
    birl.compare(exp, a_few_seconds_ago) == Lt,
    Error("JWT exp is expired"),
  )
  use <- bool.guard(
    birl.compare(iat, a_few_seconds_later) == Gt,
    Error("JWT iat is in the future"),
  )

  Ok(claims)
}

fn validate_nonce(claims: Claims, provider: DataProvider) {
  use nonce <- result.try(get_claim(claims, "nonce", decode.string))

  case data_provider.validate_nonce(provider, nonce) {
    Ok(_) -> Ok(claims)

    Error(_) -> {
      logger.error_meta("Failed to validate nonce", claims)

      Error("Invalid nonce")
    }
  }
}

fn validate_lti_resource_link_request_message(
  claims: Claims,
) -> Result(Dict(String, Dynamic), String) {
  case get_claim(claims, message_type_claim, decode.string) {
    Ok("LtiResourceLinkRequest") -> Ok(claims)
    _ -> {
      logger.error_meta("Invalid message type", #(claims, message_type_claim))

      Error("Invalid message type")
    }
  }
}

const message_validators = [
  #("LtiResourceLinkRequest", validate_lti_resource_link_request_message),
]

fn validate_message(claims: Claims) {
  use message_type <- result.try(get_claim(
    claims,
    message_type_claim,
    decode.string,
  ))

  use #(_, validator) <- result.try(
    list.find(message_validators, fn(validator) { validator.0 == message_type })
    |> result.replace_error(
      "No validator found for message type " <> message_type,
    ),
  )

  validator(claims)
  |> result.replace_error("Invalid message type " <> message_type)
}

fn get_claim(
  claims: Claims,
  claim: String,
  decoder: Decoder(a),
) -> Result(a, String) {
  dict.get(claims, claim)
  |> result.map(fn(c) {
    decode.run(c, decoder)
    |> result.replace_error("Invalid claim " <> claim)
  })
  |> result.replace_error("Missing claim " <> claim)
  |> result.flatten()
}
