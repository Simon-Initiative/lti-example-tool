import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import lti/providers/http_provider.{type HttpProvider}
import lti/services/access_token.{type AccessToken, AccessToken}
import lti/services/ags/line_item.{type LineItem, LineItem}
import lti/services/ags/score.{type Score}
import lti/utils.{json_decoder}

pub const lti_ags_claim_url = "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint"

pub const lineitem_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"

pub const result_readonly_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly"

pub const scores_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/score"

pub fn post_score(
  http_provider: HttpProvider,
  score: Score,
  line_item: LineItem,
  access_token: AccessToken,
) -> Result(String, String) {
  let url = build_url_with_path(line_item.id, "scores")
  let body =
    score.to_json(score)
    |> json.to_string()

  use req <- result.try(
    request.to(url)
    |> result.replace_error("Error creating request for URL " <> url),
  )

  let req =
    req
    |> set_score_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Post)
    |> request.set_body(body)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 -> Ok(res.body)
        _ -> Error("Error posting score")
      }

    _ -> Error("Error posting score")
  }
}

pub fn fetch_or_create_line_item(
  http_provider: HttpProvider,
  line_items_service_url: String,
  resource_id: String,
  maximum_score_provider: fn() -> Float,
  label: String,
  access_token: AccessToken,
) -> Result(LineItem, String) {
  let url =
    build_url_with_params(line_items_service_url, [
      #("resource_id", resource_id),
      #("limit", "1"),
    ])

  use req <- result.try(
    request.to(url)
    |> result.replace_error("Error creating request for URL " <> url),
  )

  let req =
    req
    |> set_line_items_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Get)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 -> {
          case
            json.decode(
              res.body,
              json_decoder(decode.list(line_item.decoder())),
            )
          {
            Ok([]) ->
              create_line_item(
                http_provider,
                line_items_service_url,
                resource_id,
                maximum_score_provider(),
                label,
                access_token,
              )

            Ok([raw_line_item, ..]) -> Ok(raw_line_item)

            _ -> Error("Error decoding line items")
          }
        }

        _ -> Error("Error retrieving existing line items")
      }

    _ -> Error("Error retrieving existing line items")
  }
}

pub fn create_line_item(
  http_provider: HttpProvider,
  line_items_service_url: String,
  resource_id: String,
  score_maximum: Float,
  label: String,
  access_token: AccessToken,
) -> Result(LineItem, String) {
  let line_item = LineItem("", score_maximum, resource_id, label)

  let body =
    line_item.to_json(line_item)
    |> json.to_string()

  use req <- result.try(
    request.to(line_items_service_url)
    |> result.replace_error(
      "Error creating request for URL " <> line_items_service_url,
    ),
  )

  let req =
    req
    |> set_authorization_header(access_token)
    |> request.set_method(http.Post)
    |> request.set_body(body)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 -> {
          case json.decode(res.body, json_decoder(line_item.decoder())) {
            Ok(raw_line_item) -> Ok(raw_line_item)
            _ -> Error("Error creating new line item")
          }
        }
        _ -> Error("Error creating new line item")
      }

    _ -> Error("Error creating new line item")
  }
}

/// Given a set of LTI claims, returns True if the grade passback
/// feature is available for the given LTI launch.
pub fn grade_passback_available(
  lti_launch_claims: Dict(String, Dynamic),
) -> Bool {
  {
    use lti_ags_claim <- result.try(
      dict.get(lti_launch_claims, lti_ags_claim_url)
      |> result.replace_error(False)
      |> result.then(fn(c) {
        decode.run(c, decode.dict(decode.string, decode.string))
        |> result.replace_error(False)
      }),
    )

    use scopes <- result.try(
      dict.get(lti_ags_claim, "scope") |> result.replace_error(False),
    )

    let scopes = string.split(scopes, " ")

    Ok(list.contains(scopes, result_readonly_scope_url))
  }
  |> result.unwrap_both()
}

fn set_line_items_headers(req: Request(String)) -> Request(String) {
  req
  |> request.set_header(
    "Content-Type",
    "application/vnd.ims.lis.v2.lineitem+json",
  )
  |> request.set_header(
    "Accept",
    "application/vnd.ims.lis.v2.lineitemcontainer+json",
  )
}

fn set_score_headers(req: Request(String)) -> Request(String) {
  req
  |> request.set_header("Content-Type", "application/vnd.ims.lis.v1.score+json")
  |> request.set_header(
    "Accept",
    "application/vnd.ims.lis.v2.lineitemcontainer+json",
  )
}

fn set_authorization_header(
  req: Request(String),
  access_token: AccessToken,
) -> Request(String) {
  let AccessToken(access_token: access_token, ..) = access_token

  req
  |> request.set_header("Authorization", "Bearer " <> access_token)
}

fn build_url_with_path(base: String, path: String) -> String {
  case string.split(base, "?") {
    [base, query] -> base <> "/" <> path <> "?" <> query
    _ -> base <> "/" <> path
  }
}

fn build_url_with_params(
  base: String,
  params: List(#(String, String)),
) -> String {
  case uri.parse_query(base) {
    Ok(base_params) ->
      base <> "?" <> uri.query_to_string(list.append(base_params, params))
    _ -> base <> "?" <> uri.query_to_string(params)
  }
}
