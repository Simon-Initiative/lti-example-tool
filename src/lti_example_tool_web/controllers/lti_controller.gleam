import birl
import formal/form
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/function
import gleam/http
import gleam/http/cookie
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import gleam/uri
import lightbulb
import lightbulb/jose
import lightbulb/jwk.{type Jwk}
import lightbulb/services/access_token
import lightbulb/services/ags
import lightbulb/services/ags/line_item.{LineItem}
import lightbulb/services/ags/score.{Score}
import lightbulb/services/nrps
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/database.{type Record, Record}
import lti_example_tool/jwks
import lti_example_tool/oidc_states
import lti_example_tool/registrations
import lti_example_tool/utils/logger
import lti_example_tool_web/cookies.{require_cookie, set_cookie}
import lti_example_tool_web/html.{render_html, render_html_status} as _
import lti_example_tool_web/html/components/page.{error_page}
import lti_example_tool_web/html/lti_html
import wisp.{type Request, type Response, redirect}

const launch_session_cookie_name = "launch_session"

const roles_claim = "https://purl.imsglobal.org/spec/lti/claim/roles"

const context_claim = "https://purl.imsglobal.org/spec/lti/claim/context"

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

  case lightbulb.oidc_login(app.providers.data, params) {
    Ok(#(state, redirect_url)) -> {
      case oidc_states.create(app.db, state) {
        Ok(_) -> redirect(to: redirect_url)
        Error(e) -> {
          logger.error_meta("Failed to persist oidc state", e)

          render_html(error_page("OIDC login failed: unable to persist state"))
        }
      }
    }
    Error(error) -> render_html(error_page("OIDC login failed: " <> error))
  }
}

pub fn validate_launch(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)
  let session_state = case dict.get(params, "state") {
    Ok(state) ->
      case oidc_states.consume(app.db, state) {
        Ok(state) -> Ok(state)
        Error(e) -> {
          logger.error_meta("Invalid launch state", e)

          Error(render_html(error_page("Invalid or expired launch state")))
        }
      }
    Error(_) -> {
      logger.error("Required 'state' parameter not found")

      Error(render_html(error_page("Required 'state' parameter not found")))
    }
  }

  case session_state {
    Ok(session_state) ->
      case
        lightbulb.validate_launch(app.providers.data, params, session_state)
      {
        Ok(claims) -> {
          case launch_session_from_claims(claims) {
            Ok(session) -> {
              use <- set_cookie(
                launch_session_cookie_name,
                encode_launch_session(session),
                cookie.Attributes(
                  ..cookie.defaults(http.Https),
                  same_site: Some(cookie.None),
                  max_age: option.Some(60 * 60 * 8),
                ),
              )

              render_html(lti_html.launch_details(claims, app))
            }
            Error(e) -> {
              logger.error_meta("Failed to create launch session", e)

              render_html(error_page("Failed to process launch claims"))
            }
          }
        }
        Error(e) -> {
          logger.error_meta("Invalid launch", e)

          render_html(error_page("Invalid launch: " <> string.inspect(e)))
        }
      }
    Error(response) -> response
  }
}

pub fn current_user(req: Request, _app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Get)
  use cookie_value <- require_cookie(
    req,
    launch_session_cookie_name,
    or_else: fn() { unauthorized_response() },
  )

  case decode_launch_session(cookie_value) {
    Ok(session) ->
      dict.from_list([
        #("sub", session.sub),
        #("name", session.name),
        #("email", session.email),
        #("issuer", session.issuer),
        #("audience", session.audience),
        #("roles", string.join(session.roles, ", ")),
        #("context_title", session.context_title),
      ])
      |> json.dict(function.identity, json.string)
      |> json.to_string()
      |> wisp.json_response(200)
    Error(e) -> {
      logger.error_meta("Invalid launch session cookie", e)
      unauthorized_response()
    }
  }
}

pub fn app(req: Request, _app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Get)
  use _ <- require_cookie(req, launch_session_cookie_name, or_else: fn() {
    render_html_status(error_page("Unauthorized"), 401)
  })

  render_html(lti_html.client_app())
}

fn unauthorized_response() -> Response {
  dict.from_list([#("error", "Unauthorized")])
  |> json.dict(function.identity, json.string)
  |> json.to_string()
  |> wisp.json_response(401)
}

fn launch_session_from_claims(
  claims: Dict(String, Dynamic),
) -> Result(LaunchSession, String) {
  use sub <- result.try(required_string_claim(claims, "sub"))
  use issuer <- result.try(required_string_claim(claims, "iss"))
  use audience <- result.try(required_audience_claim(claims))
  let name = optional_string_claim(claims, "name") |> result.unwrap(sub)
  let email = optional_string_claim(claims, "email") |> result.unwrap("")
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

fn required_string_claim(
  claims: Dict(String, Dynamic),
  key: String,
) -> Result(String, String) {
  use claim <- result.try(
    dict.get(claims, key)
    |> result.replace_error("Missing required claim: " <> key),
  )

  decode.run(claim, decode.string)
  |> result.replace_error("Invalid required claim: " <> key)
}

fn optional_string_claim(claims: Dict(String, Dynamic), key: String) {
  case dict.get(claims, key) {
    Ok(claim) ->
      decode.run(claim, decode.string)
      |> result.replace_error("Invalid optional claim: " <> key)
    Error(_) -> Error("Missing optional claim: " <> key)
  }
}

fn required_audience_claim(
  claims: Dict(String, Dynamic),
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

fn optional_roles_claim(claims: Dict(String, Dynamic)) -> List(String) {
  case dict.get(claims, roles_claim) {
    Ok(claim) ->
      decode.run(claim, decode.list(decode.string)) |> result.unwrap([])
    Error(_) -> []
  }
}

fn optional_context_title_claim(claims: Dict(String, Dynamic)) -> String {
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

fn decode_launch_session(value: String) -> Result(LaunchSession, String) {
  case string.split(value, "|") {
    [sub, name, email, issuer, audience, roles, context_title] -> {
      use sub <- result.try(percent_decode("sub", sub))
      use name <- result.try(percent_decode("name", name))
      use email <- result.try(percent_decode("email", email))
      use issuer <- result.try(percent_decode("issuer", issuer))
      use audience <- result.try(percent_decode("audience", audience))
      use raw_roles <- result.try(percent_decode("roles", roles))
      use context_title <- result.try(percent_decode(
        "context_title",
        context_title,
      ))

      let roles =
        raw_roles
        |> string.split(",")
        |> list.filter(fn(role) { role != "" })

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
    _ -> Error("Invalid launch session cookie format")
  }
}

fn percent_decode(label: String, value: String) -> Result(String, String) {
  uri.percent_decode(value)
  |> result.replace_error("Invalid encoded launch session field: " <> label)
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
          |> result.replace_error("Error fetching access token"),
        )

        let score =
          Score(
            score_given: score_given,
            score_maximum: score_maximum,
            timestamp: birl.now() |> birl.to_iso8601(),
            user_id: user_id,
            comment: comment,
            activity_progress: "Completed",
            grading_progress: "FullyGraded",
          )

        // Ensure the line item exists by fetching the existing one or creating a new one
        use line_item <- result.try(ags.fetch_or_create_line_item(
          app.providers.http,
          line_items_service_url,
          resource_id,
          fn() { 1.0 },
          line_item_name,
          access_token,
        ))

        // Post the score to the line item
        ags.post_score(app.providers.http, score, line_item, access_token)
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
          |> result.replace_error("Error fetching access token"),
        )

        let score =
          Score(
            score_given: score_given,
            score_maximum: score_maximum,
            timestamp: birl.now() |> birl.to_iso8601(),
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
          )

        // Post the score to the single line item
        ags.post_score(app.providers.http, score, line_item, access_token)
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
      |> result.replace_error("Error fetching access token"),
    )

    nrps.fetch_memberships(
      app.providers.http,
      context_memberships_url,
      access_token,
    )
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
