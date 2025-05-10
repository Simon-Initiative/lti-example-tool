import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri
import lti/providers/http_provider.{type HttpProvider}
import lti/services/access_token.{type AccessToken, AccessToken}
import lti/services/ags/line_item.{type LineItem, LineItem}
import lti/services/ags/score.{type Score}
import lti/utils.{json_decoder}
import lti_example_tool/utils/logger

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
        _ -> Error("Unexpected status: " <> string.inspect(res))
      }

    e -> Error("Error posting score: " <> string.inspect(e))
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
  let line_item =
    LineItem(
      id: "",
      score_maximum: score_maximum,
      label: label,
      resource_id: resource_id,
    )

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
    |> set_line_items_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Post)
    |> request.set_body(body)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 -> {
          json.decode(res.body, json_decoder(line_item.decoder()))
          |> result.map_error(fn(e) {
            "Error decoding line item: " <> string.inspect(e)
          })
        }
        e -> {
          logger.error_meta("Error creating line item", res)
          Error("Unexpected status: " <> string.inspect(e))
        }
      }

    e -> {
      logger.error_meta("Error creating line item", e)
      Error("Error creating new line item")
    }
  }
}

/// Given a set of LTI claims, returns True if the grade passback
/// feature is available for the given LTI launch.
pub fn grade_passback_available(
  lti_launch_claims: Dict(String, Dynamic),
) -> Bool {
  {
    use lti_ags_claim <- result.try(
      get_lti_ags_claim(lti_launch_claims) |> result.replace_error(False),
    )

    Ok(list.contains(lti_ags_claim.scope, result_readonly_scope_url))
  }
  |> result.unwrap_both()
}

pub fn get_line_items_service_url(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(String, String) {
  {
    use lti_ags_claim <- result.try(get_lti_ags_claim(lti_launch_claims))

    Ok(lti_ags_claim.lineitems)
  }
}

type LtiAgsClaim {
  LtiAgsClaim(
    lineitems: String,
    scope: List(String),
    errors: Dict(String, Dynamic),
    validation_context: Option(Dynamic),
  )
}

fn get_lti_ags_claim(
  claims: Dict(String, Dynamic),
) -> Result(LtiAgsClaim, String) {
  let lti_ags_claim_decoder = {
    use lineitems <- decode.field("lineitems", decode.string)
    use scope <- decode.field("scope", decode.list(decode.string))
    use errors <- decode.field(
      "errors",
      decode.dict(decode.string, decode.dynamic),
    )
    use validation_context <- decode.field(
      "validation_context",
      decode.optional(decode.dynamic),
    )

    decode.success(LtiAgsClaim(
      lineitems: lineitems,
      scope: scope,
      errors: errors,
      validation_context: validation_context,
    ))
  }

  dict.get(claims, lti_ags_claim_url)
  |> result.replace_error("Missing LTI AGS claim")
  |> result.then(fn(c) {
    decode.run(c, lti_ags_claim_decoder)
    |> result.replace_error("Invalid LTI AGS claim")
  })
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
