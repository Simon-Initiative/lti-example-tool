import gleam/http
import gleam/httpc
import gleam/json
import gleam/string
import lti/services/access_token.{type AccessToken}
import lti/services/ags/line_item.{type LineItem}
import lti/services/ags/score.{type Score}

pub const lti_ags_claim_url = "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint"

pub const lineitem_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"

pub const result_readonly_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly"

pub const scores_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/score"
// pub fn post_score(
//   score: Score,
//   line_item: LineItem,
//   access_token: AccessToken,
// ) -> Result(String, String) {
//   let url = build_url_with_path(line_item.id, "scores")
//   let body = json.encode(score)
//   let headers = score_headers(access_token)

//   httpc.post(url, body, headers)
//   |> case {
//     Ok(response) if response.status in [200, 201] -> Ok(response.body)
//     _ -> Error("Error posting score")
//   }
// }

// pub fn fetch_or_create_line_item(
//   line_items_service_url: String,
//   resource_id: String,
//   maximum_score_provider: fn() -> Float,
//   label: String,
//   access_token: AccessToken,
// ) -> Result(LineItem, String) {
//   let prefixed_resource_id = resource_id
//   let request_url = build_url_with_params(line_items_service_url, "resource_id=\(prefixed_resource_id)&limit=1")

//   http.get(request_url, headers(access_token))
//   |> case {
//     Ok(response) if response.status in [200, 201] ->
//       json.decode(response.body)
//       |> case {
//         Ok([]) -> create_line_item(line_items_service_url, resource_id, maximum_score_provider(), label, access_token)
//         Ok([raw_line_item, ..]) -> Ok(to_line_item(raw_line_item))
//         _ -> Error("Error retrieving existing line items")
//       }
//     _ -> Error("Error retrieving existing line items")
//   }
// }

// pub fn create_line_item(
//   line_items_service_url: String,
//   resource_id: String,
//   score_maximum: Float,
//   label: String,
//   access_token: AccessToken,
// ) -> Result(LineItem, String) {
//   let line_item = LineItem("", score_maximum, resource_id, label)
//   let body = json.encode(line_item)

//   http.post(line_items_service_url, body, headers(access_token))
//   |> case {
//     Ok(response) if response.status in [200, 201] ->
//       json.decode(response.body)
//       |> case {
//         Ok(raw_line_item) -> Ok(to_line_item(raw_line_item))
//         _ -> Error("Error creating new line item")
//       }
//     _ -> Error("Error creating new line item")
//   }
// }

// pub fn grade_passback_enabled?(lti_launch_params: Map(String, String)) -> Bool {
//   lti_launch_params
//   |> map.get(lti_ags_claim_url)
//   |> case {
//     None -> False
//     Some(config) ->
//       map.has_key(config, "lineitems") &&
//       has_scope?(config, lineitem_scope_url) &&
//       has_scope?(config, scores_scope_url)
//   }
// }

// fn to_line_item(raw_line_item: Map(String, String)) -> LineItem {
//   LineItem(
//     id: map.get(raw_line_item, "id") |> unwrap_or(""),
//     score_maximum: map.get(raw_line_item, "scoreMaximum") |> unwrap_or(0.0),
//     resource_id: map.get(raw_line_item, "resourceId") |> unwrap_or(""),
//     label: map.get(raw_line_item, "label") |> unwrap_or("")
//   )
// }

// fn headers(access_token: AccessToken) -> List(http.Header) {
//   [
//     http.header("Accept", "application/vnd.ims.lis.v2.lineitemcontainer+json"),
//     http.header("Content-Type", "application/vnd.ims.lis.v2.lineitem+json"),
//     access_token_header(access_token)
//   ]
// }

// fn score_headers(access_token: AccessToken) -> List(http.Header) {
//   [
//     http.header("Content-Type", "application/vnd.ims.lis.v1.score+json"),
//     access_token_header(access_token)
//   ]
// }

// fn access_token_header(AccessToken(access_token)) -> http.Header {
//   http.header("Authorization", "Bearer \(access_token)")
// }

// fn build_url_with_path(base_url: String, path_to_add: String) -> String {
//   string.split(base_url, "?")
//   |> case {
//     [base, query] -> "\(base)/\(path_to_add)?\(query)"
//     _ -> "\(base_url)/\(path_to_add)"
//   }
// }

// fn build_url_with_params(base_url: String, params_to_add: String) -> String {
//   string.split(base_url, "?")
//   |> case {
//     [base, query] -> "\(base)?\(query)&\(params_to_add)"
//     _ -> "\(base_url)?\(params_to_add)"
//   }
// }

// fn has_scope?(lti_ags_claim: Map(String, String), scope_url: String) -> Bool {
//   lti_ags_claim
//   |> map.get("scope")
//   |> option.map(fn scopes -> list.member(scopes, scope_url) end)
//   |> unwrap_or(False)
// }
