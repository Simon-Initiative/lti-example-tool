import birl
import formal/form
import gleam/dict.{type Dict}
import gleam/function
import gleam/http
import gleam/http/cookie
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import lightbulb/jose
import lightbulb/jwk.{type Jwk}
import lightbulb/services/access_token
import lightbulb/services/ags
import lightbulb/services/ags/score.{Score}
import lightbulb/services/nrps
import lightbulb/tool
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/cookies.{require_cookie, set_cookie}
import lti_example_tool/database.{type Record, Record}
import lti_example_tool/html.{render_html} as _
import lti_example_tool/html/components/page.{error_page}
import lti_example_tool/html/lti_html
import lti_example_tool/jwks
import lti_example_tool/registrations
import lti_example_tool/utils/logger
import wisp.{type Request, type Response, redirect}

pub fn oidc_login(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)

  case tool.oidc_login(app.providers.data, params) {
    Ok(#(state, redirect_url)) -> {
      use <- set_cookie(
        "state",
        state,
        cookie.Attributes(
          ..cookie.defaults(http.Https),
          same_site: Some(cookie.None),
          max_age: option.Some(60 * 60 * 24),
        ),
      )

      redirect(to: redirect_url)
    }
    Error(error) -> render_html(error_page("OIDC login failed: " <> error))
  }
}

pub fn validate_launch(req: Request, app: AppContext) -> Response {
  use params <- all_params(req)
  use session_state <- require_cookie(req, "state", or_else: fn() {
    logger.error("Required 'state' cookie not found")

    render_html(error_page("Required 'state' cookie not found"))
  })

  case tool.validate_launch(app.providers.data, params, session_state) {
    Ok(claims) -> {
      render_html(lti_html.launch_details(claims, app))
    }
    Error(e) -> {
      logger.error_meta("Invalid launch", e)

      render_html(error_page("Invalid launch: " <> string.inspect(e)))
    }
  }
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
  SendScoreForm(
    line_item_id: String,
    line_item_name: String,
    score_given: Float,
    score_maximum: Float,
    comment: String,
    user_id: String,
    registration_id: Int,
    line_items_service_url: String,
  )
}

pub fn send_score(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)

  let form =
    form.decoding({
      use line_item_id <- form.parameter
      use line_item_name <- form.parameter
      use score_given <- form.parameter
      use score_maximum <- form.parameter
      use comment <- form.parameter
      use user_id <- form.parameter
      use registration_id <- form.parameter
      use line_items_service_url <- form.parameter

      SendScoreForm(
        line_item_id,
        line_item_name,
        score_given,
        score_maximum,
        comment,
        user_id,
        registration_id,
        line_items_service_url,
      )
    })
    |> form.with_values(formdata.values)
    |> form.field(
      "line_item_id",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.field(
      "line_item_name",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.field(
      "score_given",
      form.float |> form.and(form.must_be_greater_float_than(0.0)),
    )
    |> form.field(
      "score_maximum",
      form.float |> form.and(form.must_be_greater_float_than(0.0)),
    )
    |> form.field("comment", form.string)
    |> form.field("user_id", form.string)
    |> form.field("registration_id", form.int)
    |> form.field("line_items_service_url", form.string)
    |> form.finish()

  case form {
    Ok(SendScoreForm(
      line_item_id,
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
          line_item_id,
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
    Error(e) -> {
      logger.error_meta("Invalid form data", e)

      render_html(error_page("Invalid form data: " <> string.inspect(e)))
    }
  }
}

type MembershipForm {
  MembershipForm(context_memberships_url: String, registration_id: Int)
}

pub fn fetch_memberships(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use MembershipForm(context_memberships_url, registration_id) <- result.try(
      form.decoding({
        use context_memberships_url <- form.parameter
        use registration_id <- form.parameter

        MembershipForm(context_memberships_url, registration_id)
      })
      |> form.with_values(formdata.values)
      |> form.field(
        "context_memberships_url",
        form.string
          |> form.and(form.must_not_be_empty),
      )
      |> form.field("registration_id", form.int)
      |> form.finish
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
      |> json.to_string_tree()
      |> wisp.json_response(200)
    }
    Error(e) -> {
      logger.error_meta("Error fetching JWKS", e)

      render_html(error_page("Error fetching JWKS: " <> string.inspect(e)))
    }
  }
}
