import formal/form
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/function
import gleam/http
import gleam/http/cookie
import gleam/http/request
import gleam/http/response as http_response
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import gleam/uri
import lightbulb/deep_linking
import lightbulb/deep_linking/content_item
import lightbulb/errors
import lightbulb/jose
import lightbulb/jwk.{type Jwk}
import lightbulb/services/access_token
import lightbulb/services/ags
import lightbulb/services/ags/line_item.{LineItem}
import lightbulb/services/ags/score.{Score}
import lightbulb/services/nrps
import lightbulb/tool
import lti_example_tool/api_tokens
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/config
import lti_example_tool/database.{type Record, Record}
import lti_example_tool/deep_link_resources
import lti_example_tool/deep_linking_contexts
import lti_example_tool/jwks
import lti_example_tool/registrations
import lti_example_tool/tokens
import lti_example_tool/users
import lti_example_tool/utils/logger
import lti_example_tool_web/cookies.{set_cookie}
import lti_example_tool_web/html.{render_html} as _
import lti_example_tool_web/html/components/page.{error_page}
import lti_example_tool_web/html/lti_html
import wisp.{type Request, type Response, redirect}

const launch_session_cookie_name = "launch_session"

const roles_claim = "https://purl.imsglobal.org/spec/lti/claim/roles"

const context_claim = "https://purl.imsglobal.org/spec/lti/claim/context"

const resource_link_message_type = "LtiResourceLinkRequest"

const custom_claim = "https://purl.imsglobal.org/spec/lti/claim/custom"

const deep_linking_context_ttl_seconds = 600

type LaunchSession {
  LaunchSession(
    sub: String,
    name: String,
    email: String,
    issuer: String,
    audience: String,
    roles: List(String),
    context_title: String,
  )
}

pub fn oidc_login(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)

  case tool.oidc_login(app.providers.data, params) {
    Ok(#(_, redirect_url)) -> redirect(to: redirect_url)
    Error(error) ->
      render_html(error_page(
        "OIDC login failed: " <> errors.core_error_to_string(error),
      ))
  }
}

pub fn validate_launch(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)
  let session_state = case dict.get(params, "state") {
    Ok(state) -> Ok(state)
    Error(_) -> {
      logger.error("Required 'state' parameter not found")

      Error(render_html(error_page("Required 'state' parameter not found")))
    }
  }

  case session_state {
    Ok(session_state) ->
      case tool.validate_launch(app.providers.data, params, session_state) {
        Ok(claims) -> route_launch_by_message_type(claims, app)
        Error(e) -> {
          logger.error_meta("Invalid launch", e)

          render_html(error_page(
            "Invalid launch: " <> errors.core_error_to_string(e),
          ))
        }
      }
    Error(response) -> response
  }
}

pub fn respond_deep_linking(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)
  let params = dict.from_list(formdata.values)

  let result = {
    use context_token <- result.try(required_param(params, "context_token"))
    use resource_id <- result.try(required_param(params, "resource_id"))
    use selected_resource <- result.try(deep_link_resources.parse(resource_id))
    use context <- result.try(
      deep_linking_contexts.consume_context(app.db, context_token)
      |> result.map_error(deep_linking_contexts.consume_error_to_string),
    )
    use active_jwk <- result.try(
      jwks.get_active_jwk(app.db)
      |> result.map(fn(record) { record.data })
      |> result.replace_error("Failed to load active signing key"),
    )

    let response_jwt =
      build_deep_linking_response_jwt(context, selected_resource, active_jwk)

    use jwt <- result.try(response_jwt)

    let response_html =
      deep_linking.build_response_form_post(context.deep_link_return_url, jwt)
      |> result.map_error(errors.deep_linking_error_to_string)

    use html <- result.try(response_html)

    Ok(#(context, selected_resource, html))
  }

  case result {
    Ok(#(context, selected_resource, html)) -> {
      logger.info_meta("Deep-linking response generated", #(
        context.iss,
        context.deployment_id,
        deep_link_resources.id(selected_resource),
      ))

      wisp.ok()
      |> http_response.set_header("content-type", "text/html; charset=utf-8")
      |> wisp.string_body(html)
    }
    Error(error) -> {
      logger.error_meta("Deep-linking response failed", error)

      render_html(error_page(
        "Unable to complete deep-linking response. Please restart the deep-link launch from your platform.",
      ))
    }
  }
}

fn route_launch_by_message_type(
  claims: Dict(String, dynamic.Dynamic),
  app: AppContext,
) -> Response {
  case message_type_from_claims(claims) {
    Ok(message_type) if message_type == resource_link_message_type ->
      handle_resource_link_launch(claims, app)
    Ok(message_type)
      if message_type == deep_linking.lti_message_type_deep_linking_request
    -> handle_deep_linking_launch(claims, app)
    Ok(message_type) -> {
      logger.error("Unsupported LTI message type: " <> message_type)
      render_html(error_page("Unsupported LTI message type"))
    }
    Error(error) -> {
      logger.error_meta("Failed to read LTI message type", error)
      render_html(error_page("Failed to process launch claims"))
    }
  }
}

fn handle_resource_link_launch(
  claims: Dict(String, dynamic.Dynamic),
  app: AppContext,
) -> Response {
  case launch_session_from_claims(claims) {
    Ok(session) -> {
      case
        users.upsert(
          app.db,
          users.User(
            sub: session.sub,
            name: session.name,
            email: session.email,
            issuer: session.issuer,
            audience: session.audience,
            roles: string.join(session.roles, ", "),
            context_title: session.context_title,
          ),
        )
      {
        Ok(user_record) ->
          case
            tokens.create_bootstrap_token(
              app.db,
              user_record.id,
              config.bootstrap_token_ttl_seconds(),
            )
          {
            Ok(bootstrap_token) -> {
              use <- set_cookie(
                launch_session_cookie_name,
                encode_launch_session(session),
                cookie.Attributes(
                  ..cookie.defaults(http.Https),
                  same_site: Some(cookie.None),
                  max_age: option.Some(60 * 60 * 8),
                ),
              )

              render_html(lti_html.launch_details(
                claims,
                app,
                bootstrap_token,
                selected_resource_title_from_claims(claims),
              ))
            }
            Error(e) -> {
              logger.error_meta("Failed to create bootstrap token", e)
              render_html(error_page("Failed to create bootstrap token"))
            }
          }
        Error(e) -> {
          logger.error_meta("Failed to upsert user", e)
          render_html(error_page("Failed to persist launch user"))
        }
      }
    }
    Error(e) -> {
      logger.error_meta("Failed to create launch session", e)

      render_html(error_page("Failed to process launch claims"))
    }
  }
}

fn handle_deep_linking_launch(
  claims: Dict(String, dynamic.Dynamic),
  app: AppContext,
) -> Response {
  let result = {
    use deep_linking_settings <- result.try(
      deep_linking.get_deep_linking_settings(claims)
      |> result.map_error(errors.deep_linking_error_to_string),
    )
    use issuer <- result.try(required_string_claim(claims, "iss"))
    use audience <- result.try(required_audience_claim(claims))
    use deployment_id <- result.try(required_string_claim(
      claims,
      deep_linking.claim_deployment_id,
    ))
    use context_token <- result.try(deep_linking_contexts.create_context(
      app.db,
      deep_linking_contexts.NewDeepLinkingContext(
        iss: issuer,
        aud: audience,
        deployment_id: deployment_id,
        deep_link_return_url: deep_linking_settings.deep_link_return_url,
        request_data: deep_linking_settings.data,
        accept_types: deep_linking_settings.accept_types,
        accept_multiple: deep_linking_settings.accept_multiple,
        accept_lineitem: deep_linking_settings.accept_lineitem,
        ttl_seconds: deep_linking_context_ttl_seconds,
      ),
    ))

    Ok(context_token)
  }

  case result {
    Ok(context_token) -> {
      logger.info_meta("Deep-linking launch detected", context_token)

      render_html(lti_html.deep_linking_resource_picker(context_token))
    }
    Error(error) -> {
      logger.error_meta("Failed to initialize deep-linking launch", error)

      render_html(error_page(
        "Unable to start deep-linking flow. Please retry from your platform.",
      ))
    }
  }
}

pub fn current_user(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Get)
  case require_bearer_token(req) {
    Ok(access_token) ->
      case api_tokens.verify_access_token(app.db, access_token) {
        Ok(user_id) ->
          case users.get(app.db, user_id) {
            Ok(Record(data: user, ..)) ->
              dict.from_list([
                #("sub", user.sub),
                #("name", user.name),
                #("email", user.email),
                #("issuer", user.issuer),
                #("audience", user.audience),
                #("roles", user.roles),
                #("context_title", user.context_title),
              ])
              |> json.dict(function.identity, json.string)
              |> json.to_string()
              |> wisp.json_response(200)
            Error(e) -> {
              logger.error_meta("Authenticated user not found", e)
              unauthorized_response()
            }
          }
        Error(e) -> {
          logger.error_meta("Invalid access token", e)
          unauthorized_response()
        }
      }
    Error(e) -> {
      logger.error_meta("Authorization header error", e)
      unauthorized_response()
    }
  }
}

pub fn token(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)
  let params = dict.from_list(formdata.values)

  case dict.get(params, "grant_type") {
    Ok("bootstrap") -> exchange_bootstrap_token(app, params)
    Ok("refresh_token") -> refresh_access_token(app, params)
    Ok(_) ->
      dict.from_list([#("error", "Unsupported grant_type")])
      |> json.dict(function.identity, json.string)
      |> json.to_string()
      |> wisp.json_response(400)
    Error(_) ->
      dict.from_list([
        #("error", "Missing grant_type"),
      ])
      |> json.dict(function.identity, json.string)
      |> json.to_string()
      |> wisp.json_response(400)
  }
}

pub fn app(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Get)
  render_html(lti_html.client_app(app))
}

fn unauthorized_response() -> Response {
  dict.from_list([#("error", "Unauthorized")])
  |> json.dict(function.identity, json.string)
  |> json.to_string()
  |> wisp.json_response(401)
}

fn exchange_bootstrap_token(
  app: AppContext,
  params: Dict(String, String),
) -> Response {
  case dict.get(params, "bootstrap_token") {
    Ok(raw_bootstrap_token) -> {
      case tokens.consume_bootstrap_token(app.db, raw_bootstrap_token) {
        Ok(user_id) -> issue_tokens_response(app, user_id)
        Error(e) -> {
          logger.error_meta("Invalid bootstrap token", e)

          dict.from_list([#("error", "Invalid bootstrap token")])
          |> json.dict(function.identity, json.string)
          |> json.to_string()
          |> wisp.json_response(401)
        }
      }
    }
    Error(_) ->
      dict.from_list([#("error", "Missing bootstrap_token")])
      |> json.dict(function.identity, json.string)
      |> json.to_string()
      |> wisp.json_response(400)
  }
}

fn refresh_access_token(
  app: AppContext,
  params: Dict(String, String),
) -> Response {
  case dict.get(params, "refresh_token") {
    Ok(raw_refresh_token) -> {
      case
        tokens.rotate_refresh_token(
          app.db,
          raw_refresh_token,
          config.refresh_token_ttl_seconds(),
        )
      {
        Ok(#(user_id, refresh_token)) ->
          issue_access_token_response(app, user_id, refresh_token)
        Error(e) -> {
          logger.error_meta("Invalid refresh token", e)

          dict.from_list([#("error", "Invalid refresh token")])
          |> json.dict(function.identity, json.string)
          |> json.to_string()
          |> wisp.json_response(401)
        }
      }
    }
    Error(_) ->
      dict.from_list([#("error", "Missing refresh_token")])
      |> json.dict(function.identity, json.string)
      |> json.to_string()
      |> wisp.json_response(400)
  }
}

fn issue_tokens_response(app: AppContext, user_id: Int) -> Response {
  case
    tokens.create_refresh_token(
      app.db,
      user_id,
      config.refresh_token_ttl_seconds(),
    )
  {
    Ok(refresh_token) ->
      issue_access_token_response(app, user_id, refresh_token)
    Error(e) -> {
      logger.error_meta("Failed to create refresh token", e)

      dict.from_list([#("error", "Failed to create refresh token")])
      |> json.dict(function.identity, json.string)
      |> json.to_string()
      |> wisp.json_response(500)
    }
  }
}

fn issue_access_token_response(
  app: AppContext,
  user_id: Int,
  refresh_token: String,
) -> Response {
  case
    api_tokens.issue_access_token(
      app.db,
      user_id,
      config.access_token_ttl_seconds(),
    )
  {
    Ok(access_token) ->
      json.object([
        #("access_token", json.string(access_token)),
        #("token_type", json.string("Bearer")),
        #("expires_in", json.int(config.access_token_ttl_seconds())),
        #("refresh_token", json.string(refresh_token)),
      ])
      |> json.to_string()
      |> wisp.json_response(200)
    Error(e) -> {
      logger.error_meta("Failed to issue access token", e)

      dict.from_list([#("error", "Failed to issue access token")])
      |> json.dict(function.identity, json.string)
      |> json.to_string()
      |> wisp.json_response(500)
    }
  }
}

fn require_bearer_token(req: Request) -> Result(String, String) {
  case request.get_header(req, "authorization") {
    Ok(header) -> parse_bearer_token(header)
    Error(_) -> Error("Missing Authorization header")
  }
}

fn parse_bearer_token(header: String) -> Result(String, String) {
  case string.split_once(header, " ") {
    Ok(#("Bearer", token)) if token != "" -> Ok(token)
    _ -> Error("Invalid Authorization header")
  }
}

fn launch_session_from_claims(
  claims: Dict(String, dynamic.Dynamic),
) -> Result(LaunchSession, String) {
  use sub <- result.try(required_string_claim(claims, "sub"))
  use issuer <- result.try(required_string_claim(claims, "iss"))
  use audience <- result.try(required_audience_claim(claims))
  let email = optional_string_claim(claims, "email") |> result.unwrap("")
  let name = preferred_name_from_claims(claims)
  let roles = optional_roles_claim(claims)
  let context_title = optional_context_title_claim(claims)

  Ok(LaunchSession(
    sub: sub,
    name: name,
    email: email,
    issuer: issuer,
    audience: audience,
    roles: roles,
    context_title: context_title,
  ))
}

fn preferred_name_from_claims(claims: Dict(String, dynamic.Dynamic)) -> String {
  let name = optional_string_claim(claims, "name") |> result.unwrap("")
  let given_name =
    optional_string_claim(claims, "given_name") |> result.unwrap("")
  let family_name =
    optional_string_claim(claims, "family_name") |> result.unwrap("")
  let combined_name = string.trim(given_name <> " " <> family_name)

  first_non_empty([name, combined_name])
}

fn first_non_empty(values: List(String)) -> String {
  case values {
    [value, ..rest] -> {
      let trimmed = string.trim(value)

      case trimmed == "" {
        True -> first_non_empty(rest)
        False -> trimmed
      }
    }
    [] -> ""
  }
}

fn required_string_claim(
  claims: Dict(String, dynamic.Dynamic),
  key: String,
) -> Result(String, String) {
  use claim <- result.try(
    dict.get(claims, key)
    |> result.replace_error("Missing required claim: " <> key),
  )

  decode.run(claim, decode.string)
  |> result.replace_error("Invalid required claim: " <> key)
}

fn optional_string_claim(claims: Dict(String, dynamic.Dynamic), key: String) {
  case dict.get(claims, key) {
    Ok(claim) ->
      decode.run(claim, decode.string)
      |> result.replace_error("Invalid optional claim: " <> key)
    Error(_) -> Error("Missing optional claim: " <> key)
  }
}

fn required_audience_claim(
  claims: Dict(String, dynamic.Dynamic),
) -> Result(String, String) {
  use claim <- result.try(
    dict.get(claims, "aud")
    |> result.replace_error("Missing required claim: aud"),
  )

  case decode.run(claim, decode.string) {
    Ok(audience) -> Ok(audience)
    Error(_) -> {
      case
        decode.run(claim, decode.list(decode.string))
        |> result.replace_error("Invalid required claim: aud")
      {
        Ok([audience, ..]) -> Ok(audience)
        Ok([]) -> Error("Invalid required claim: aud")
        Error(e) -> Error(e)
      }
    }
  }
}

fn message_type_from_claims(
  claims: Dict(String, dynamic.Dynamic),
) -> Result(String, String) {
  use claim <- result.try(
    dict.get(claims, tool.message_type_claim)
    |> result.replace_error("Missing required claim: message_type"),
  )

  decode.run(claim, decode.string)
  |> result.replace_error("Invalid required claim: message_type")
}

fn required_param(
  params: Dict(String, String),
  key: String,
) -> Result(String, String) {
  dict.get(params, key)
  |> result.replace_error("Missing required parameter: " <> key)
  |> result.try(fn(value) {
    case string.trim(value) {
      "" -> Error("Missing required parameter: " <> key)
      _ -> Ok(value)
    }
  })
}

fn build_deep_linking_response_jwt(
  context: deep_linking_contexts.DeepLinkingContext,
  resource: deep_link_resources.ExampleResource,
  active_jwk: Jwk,
) -> Result(String, String) {
  deep_linking.build_response_jwt_with_profile(
    deep_linking_request_claims(context),
    deep_linking_contexts.to_settings(context),
    [build_resource_content_item(resource)],
    deep_linking.default_response_options(),
    active_jwk,
    case is_canvas_context(context) {
      True -> deep_linking.Canvas
      False -> deep_linking.Standard
    },
  )
  |> result.map_error(errors.deep_linking_error_to_string)
}

fn deep_linking_request_claims(
  context: deep_linking_contexts.DeepLinkingContext,
) -> Dict(String, dynamic.Dynamic) {
  dict.from_list([
    #("iss", dynamic.string(context.iss)),
    #("aud", dynamic.string(context.aud)),
    #(deep_linking.claim_deployment_id, dynamic.string(context.deployment_id)),
  ])
}

fn is_canvas_context(context: deep_linking_contexts.DeepLinkingContext) -> Bool {
  let issuer = string.lowercase(context.iss)

  string.contains(issuer, "instructure.com")
  || string.contains(issuer, "canvas")
}

fn build_resource_content_item(
  resource: deep_link_resources.ExampleResource,
) -> content_item.ContentItem {
  content_item.lti_resource_link(
    option.Some(config.public_url() <> "/launch"),
    option.Some(deep_link_resources.title(resource)),
    option.Some("Deep-linking showcase item"),
    option.Some(
      dict.from_list([#("resource_id", deep_link_resources.id(resource))]),
    ),
    option.None,
  )
}

fn selected_resource_title_from_claims(
  claims: Dict(String, dynamic.Dynamic),
) -> Option(String) {
  case dict.get(claims, custom_claim) {
    Ok(custom_claim_value) ->
      case
        decode.run(
          custom_claim_value,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(custom_fields) ->
          case dict.get(custom_fields, "resource_id") {
            Ok(resource_id) ->
              Some(deep_link_resources.from_custom_resource_id(resource_id))
            Error(_) -> None
          }
        Error(_) -> None
      }
    Error(_) -> None
  }
}

fn optional_roles_claim(claims: Dict(String, dynamic.Dynamic)) -> List(String) {
  case dict.get(claims, roles_claim) {
    Ok(claim) ->
      decode.run(claim, decode.list(decode.string)) |> result.unwrap([])
    Error(_) -> []
  }
}

fn optional_context_title_claim(claims: Dict(String, dynamic.Dynamic)) -> String {
  case dict.get(claims, context_claim) {
    Ok(claim) -> {
      decode.run(claim, {
        use title <- decode.field("title", decode.string)

        decode.success(title)
      })
      |> result.unwrap("")
    }
    Error(_) -> ""
  }
}

fn encode_launch_session(session: LaunchSession) -> String {
  [
    session.sub,
    session.name,
    session.email,
    session.issuer,
    session.audience,
    string.join(session.roles, ","),
    session.context_title,
  ]
  |> list.map(uri.percent_encode)
  |> string.join("|")
}

fn all_params(
  req: Request,
  cb: fn(Dict(String, String)) -> Response,
) -> Response {
  use formdata <- wisp.require_form(req)

  // Combine query and body parameters into a single dictionary. Body parameters
  // take precedence over query parameters.
  let params =
    wisp.get_query(req)
    |> dict.from_list()
    |> dict.merge(dict.from_list(formdata.values))

  cb(params)
}

type SendScoreForm {
  SendLineitemsForm(
    resource_id: String,
    line_item_name: String,
    score_given: Float,
    score_maximum: Float,
    comment: String,
    user_id: String,
    registration_id: Int,
    line_items_service_url: String,
  )
  SendSingleLineitemForm(
    resource_id: String,
    score_given: Float,
    score_maximum: Float,
    comment: String,
    user_id: String,
    registration_id: Int,
    line_item_service_url: String,
  )
}

pub fn send_score(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)

  let send_score_form =
    result.or(
      decode_lineitems_form(formdata),
      decode_single_lineitem_form(formdata),
    )

  case send_score_form {
    Ok(SendLineitemsForm(
      resource_id,
      line_item_name,
      score_given,
      score_maximum,
      comment,
      user_id,
      registration_id,
      line_items_service_url,
    )) -> {
      let result = {
        use _ <- result.try(case score_given >. score_maximum {
          True -> Error("score_given cannot be greater than score_maximum")
          False -> Ok(Nil)
        })

        use registration <- result.try(
          registrations.get(app.db, registration_id)
          |> result.replace_error("Error fetching registration")
          |> result.map(fn(record) { record.data }),
        )

        use access_token <- result.try(
          access_token.fetch_access_token(app.providers, registration, [
            ags.lineitem_scope_url,
            ags.result_readonly_scope_url,
            ags.scores_scope_url,
          ])
          |> result.map_error(access_token.access_token_error_to_string),
        )

        let score =
          Score(
            score_given: score_given,
            score_maximum: score_maximum,
            timestamp: timestamp.system_time()
              |> timestamp.to_rfc3339(calendar.utc_offset),
            user_id: user_id,
            comment: comment,
            activity_progress: "Completed",
            grading_progress: "FullyGraded",
          )

        // Ensure the line item exists by fetching the existing one or creating a new one
        use line_item <- result.try(
          ags.fetch_or_create_line_item(
            app.providers.http,
            line_items_service_url,
            resource_id,
            fn() { 1.0 },
            line_item_name,
            access_token,
          )
          |> result.map_error(ags_error_to_detailed_string),
        )

        // Post the score to the line item
        ags.post_score(app.providers.http, score, line_item, access_token)
        |> result.map_error(ags_error_to_detailed_string)
      }

      case result {
        Ok(_) -> {
          render_html(lti_html.score_sent())
        }
        Error(e) -> {
          logger.error_meta("Error sending score", e)

          render_html(error_page("Error sending score: " <> string.inspect(e)))
        }
      }
    }
    Ok(SendSingleLineitemForm(
      resource_id,
      score_given,
      score_maximum,
      comment,
      user_id,
      registration_id,
      line_item_service_url,
    )) -> {
      let result = {
        use _ <- result.try(case score_given >. score_maximum {
          True -> Error("score_given cannot be greater than score_maximum")
          False -> Ok(Nil)
        })

        use registration <- result.try(
          registrations.get(app.db, registration_id)
          |> result.replace_error("Error fetching registration")
          |> result.map(fn(record) { record.data }),
        )

        use access_token <- result.try(
          access_token.fetch_access_token(app.providers, registration, [
            ags.result_readonly_scope_url,
            ags.scores_scope_url,
          ])
          |> result.map_error(access_token.access_token_error_to_string),
        )

        let score =
          Score(
            score_given: score_given,
            score_maximum: score_maximum,
            timestamp: timestamp.system_time()
              |> timestamp.to_rfc3339(calendar.utc_offset),
            user_id: user_id,
            comment: comment,
            activity_progress: "Completed",
            grading_progress: "FullyGraded",
          )

        let line_item =
          LineItem(
            id: Some(line_item_service_url),
            score_maximum: score_maximum,
            label: "",
            resource_id: resource_id,
            resource_link_id: None,
            tag: None,
            start_date_time: None,
            end_date_time: None,
            grades_released: None,
          )

        // Post the score to the single line item
        ags.post_score(app.providers.http, score, line_item, access_token)
        |> result.map_error(ags_error_to_detailed_string)
      }

      case result {
        Ok(_) -> {
          render_html(lti_html.score_sent())
        }
        Error(e) -> {
          logger.error_meta("Error sending score", e)

          render_html(error_page("Error sending score: " <> string.inspect(e)))
        }
      }
    }
    Error(e) -> {
      logger.error_meta("Invalid form data", e)

      render_html(error_page("Invalid form data: " <> string.inspect(e)))
    }
  }
}

fn ags_error_to_detailed_string(error: ags.AgsError) -> String {
  case error {
    ags.HttpUnexpectedStatus(status, body) ->
      "unexpected AGS HTTP status: "
      <> int.to_string(status)
      <> " body: "
      <> body
    _ -> ags.ags_error_to_string(error)
  }
}

fn decode_lineitems_form(
  formdata: wisp.FormData,
) -> Result(SendScoreForm, form.Form(SendScoreForm)) {
  let schema = {
    use resource_id <- form.field("resource_id", {
      form.parse_string |> form.check_not_empty
    })
    use line_item_name <- form.field("line_item_name", {
      form.parse_string |> form.check_not_empty
    })
    use score_given <- form.field("score_given", {
      form.parse_float |> form.check_float_more_than(0.0)
    })
    use score_maximum <- form.field("score_maximum", {
      form.parse_float |> form.check_float_more_than(0.0)
    })
    use comment <- form.field("comment", {
      form.parse_string |> form.check_not_empty
    })
    use user_id <- form.field("user_id", {
      form.parse_string |> form.check_not_empty
    })
    use registration_id <- form.field("registration_id", form.parse_int)
    use line_items_service_url <- form.field("line_items_service_url", {
      form.parse_string |> form.check_not_empty
    })

    form.success(SendLineitemsForm(
      resource_id,
      line_item_name,
      score_given,
      score_maximum,
      comment,
      user_id,
      registration_id,
      line_items_service_url,
    ))
  }
  schema
  |> form.new
  |> form.set_values(formdata.values)
  |> form.run
}

fn decode_single_lineitem_form(
  formdata: wisp.FormData,
) -> Result(SendScoreForm, form.Form(SendScoreForm)) {
  let schema = {
    use resource_id <- form.field("resource_id", {
      form.parse_string |> form.check_not_empty
    })
    use score_given <- form.field("score_given", {
      form.parse_float |> form.check_float_more_than(0.0)
    })
    use score_maximum <- form.field("score_maximum", {
      form.parse_float |> form.check_float_more_than(0.0)
    })
    use comment <- form.field("comment", {
      form.parse_string |> form.check_not_empty
    })
    use user_id <- form.field("user_id", {
      form.parse_string |> form.check_not_empty
    })
    use registration_id <- form.field("registration_id", form.parse_int)
    use line_item_service_url <- form.field("line_item_service_url", {
      form.parse_string |> form.check_not_empty
    })

    form.success(SendSingleLineitemForm(
      resource_id,
      score_given,
      score_maximum,
      comment,
      user_id,
      registration_id,
      line_item_service_url,
    ))
  }
  schema
  |> form.new
  |> form.set_values(formdata.values)
  |> form.run
}

type MembershipForm {
  MembershipForm(context_memberships_url: String, registration_id: Int)
}

pub fn fetch_memberships(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use MembershipForm(context_memberships_url, registration_id) <- result.try(
      form.new({
        use context_memberships_url <- form.field("context_memberships_url", {
          form.parse_string |> form.check_not_empty
        })
        use registration_id <- form.field("registration_id", form.parse_int)

        form.success(MembershipForm(context_memberships_url, registration_id))
      })
      |> form.set_values(formdata.values)
      |> form.run
      |> result.replace_error("Invalid form data"),
    )

    use registration <- result.try(
      registrations.get(app.db, registration_id)
      |> result.replace_error("Error fetching registration")
      |> result.map(fn(record) { record.data }),
    )

    use access_token <- result.try(
      access_token.fetch_access_token(app.providers, registration, [
        nrps.context_membership_readonly_claim_url,
      ])
      |> result.map_error(access_token.access_token_error_to_string),
    )

    nrps.fetch_memberships(
      app.providers.http,
      context_memberships_url,
      access_token,
    )
    |> result.map_error(nrps.nrps_error_to_string)
  }

  case result {
    Ok(memberships) -> {
      render_html(lti_html.memberships(memberships))
    }
    Error(e) -> {
      logger.error_meta("Error fetching memberships", e)

      render_html(error_page(
        "Error fetching memberships: " <> string.inspect(e),
      ))
    }
  }
}

pub fn jwks(_req: Request, app: AppContext) -> Response {
  case jwks.all(app.db) {
    Ok(jwks) -> {
      let keys =
        jwks
        |> list.map(fn(jwk: Record(String, Jwk)) {
          let Record(data: jwk, ..) = jwk
          let #(_, jwk_map) =
            jwk.pem |> jose.from_pem() |> jose.to_public() |> jose.to_map()

          jwk_map
          |> dict.insert("kid", jwk.kid)
          |> dict.insert("alg", jwk.alg)
          |> dict.insert("typ", jwk.typ)
          |> dict.insert("use", "sig")
        })

      dict.from_list([#("keys", keys)])
      |> json.dict(
        function.identity,
        json.array(_, json.dict(_, function.identity, json.string)),
      )
      |> json.to_string()
      |> wisp.json_response(200)
    }
    Error(e) -> {
      logger.error_meta("Error fetching JWKS", e)

      render_html(error_page("Error fetching JWKS: " <> string.inspect(e)))
    }
  }
}
