import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/function
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri
import lti/data_provider.{type DataProvider}
import lti/jose
import lti/jwk.{type Jwk}
import lti/registration.{type Registration}
import lti_example_tool/utils/logger

pub type AccessToken {
  AccessToken(
    access_token: String,
    token_type: String,
    expires_in: Int,
    scope: String,
  )
}

/// Requests an OAuth2 access token. Returns Ok(AccessToken) on success, Error(_) otherwise.
///
/// As parameters, expects:
/// 1. The registration from which an access token is being requested
/// 2. A list of scopes being requested
/// 3. The host name of this instance of Torus
///
/// Examples:
///
/// ```gleam
/// fetch_access_token(registration, scopes, host)
/// // Ok(AccessToken("actual_access_token", "Bearer", 3600, "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"))
/// ```
pub fn fetch_access_token(
  provider: DataProvider,
  registration: Registration,
  scopes: List(String),
) -> Result(AccessToken, String) {
  use active_jwk <- result.try(data_provider.get_active_jwk(provider))

  let client_assertion =
    create_client_assertion(
      active_jwk,
      registration.access_token_endpoint,
      registration.client_id,
      // TODO: this should be separate auth_server url for audience
      Some(registration.auth_endpoint),
    )

  request_token(registration.access_token_endpoint, client_assertion, scopes)
}

fn request_token(
  url: String,
  client_assertion: String,
  scopes: List(String),
) -> Result(AccessToken, String) {
  let body =
    uri.query_to_string([
      #("grant_type", "client_credentials"),
      #(
        "client_assertion_type",
        "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      ),
      #("client_assertion", client_assertion),
      #("scope", string.join(scopes, " ")),
    ])

  let assert Ok(req) =
    request.to(url)
    |> result.replace_error("Error creating request for URL " <> url)

  let req =
    req
    |> request.set_header("Content-Type", "application/x-www-form-urlencoded")
    |> request.set_header("Accept", "application/json")
    |> request.set_method(http.Post)
    |> request.set_body(body)

  case httpc.send(req) {
    Ok(resp) ->
      case resp.status {
        200 | 201 -> decode_access_token(resp.body)
        _ -> {
          logger.error_meta("Error requesting access token", resp)

          Error("Error requesting access token")
        }
      }
    e -> {
      logger.error_meta("Error requesting access token", e)

      Error("Error requesting access token")
    }
  }
}

fn decode_access_token(body: String) -> Result(AccessToken, String) {
  let access_token_decoder = {
    use access_token <- decode.field("access_token", decode.string)
    use token_type <- decode.field("token_type", decode.string)
    use expires_in <- decode.field("expires_in", decode.int)
    use scope <- decode.field("scope", decode.string)

    decode.success(AccessToken(
      access_token: access_token,
      token_type: token_type,
      expires_in: expires_in,
      scope: scope,
    ))
  }

  json.decode(body, json_decoder(access_token_decoder))
  |> result.map_error(fn(e) {
    "Error decoding access token" <> string.inspect(e)
  })
}

fn json_decoder(
  deocder: decode.Decoder(a),
) -> fn(Dynamic) -> Result(a, List(dynamic.DecodeError)) {
  fn(json: Dynamic) -> Result(a, List(dynamic.DecodeError)) {
    decode.run(json, deocder)
    |> result.map_error(map_decode_errors_to_dynamic_errors)
  }
}

fn map_decode_errors_to_dynamic_errors(
  errors: List(decode.DecodeError),
) -> List(dynamic.DecodeError) {
  list.map(errors, fn(error) {
    let decode.DecodeError(expected, found, path) = error

    dynamic.DecodeError(expected, found, path)
  })
}

fn create_client_assertion(
  active_jwk: Jwk,
  auth_token_url: String,
  client_id: String,
  auth_audience: Option(String),
) -> String {
  let #(_, jwk) = jose.generate_key(jose.Rsa(2048)) |> jose.to_map()

  let jwt =
    dict.from_list([
      #("iss", client_id),
      #("aud", audience(auth_token_url, auth_audience)),
      #("sub", client_id),
    ])

  // let #(jose_jwt, _jose_jws) = jose.sign(jose_jwk, jose.from_binary(jwt_string))
  let #(_, jose_jwt) = jose.sign(jwk, jwt)
  let #(_, compact_signed) = jose.compact(jose_jwt)

  echo compact_signed
}

fn audience(auth_token_url: String, auth_audience: Option(String)) -> String {
  case auth_audience {
    None -> auth_token_url
    Some("") -> auth_token_url
    Some(audience) -> audience
  }
}
