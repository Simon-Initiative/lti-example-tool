import birl
import gleam/dict.{type Dict}
import gleam/float
import gleam/function
import gleam/http
import gleam/http/cookie
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import lti/jose
import lti/jwk.{type Jwk}
import lti/services/access_token
import lti/services/ags
import lti/services/ags/score.{Score}
import lti/services/nrps
import lti/tool
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

fn all_params(
  req: Request,
  cb: fn(Dict(String, String)) -> Response,
) -> Response {
  use formdata <- wisp.require_form(req)

  // Combine query and body parameters into a single dictionary
  let query_params = wisp.get_query(req) |> dict.from_list()

  let body_params =
    formdata.values
    |> list.fold(dict.new(), fn(acc, field) {
      let #(key, value) = field
      dict.insert(acc, key, value)
    })

  let params = dict.merge(query_params, body_params)

  cb(params)
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

fn require_form_field(
  formdata: wisp.FormData,
  key: String,
) -> Result(String, String) {
  list.key_find(formdata.values, key)
  |> result.replace_error("Missing " <> key)
}

fn parse_as_float(str: String) -> Result(Float, String) {
  str
  |> float.parse()
  |> result.lazy_or(fn() {
    int.parse(str)
    |> result.map(int.to_float)
  })
  |> result.replace_error("Invalid number: " <> str)
}

pub fn send_score(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use line_item_id <- result.try(require_form_field(formdata, "line_item_id"))
    use line_item_name <- result.try(require_form_field(
      formdata,
      "line_item_name",
    ))

    use score_given <- result.try(
      require_form_field(formdata, "score_given")
      |> result.then(parse_as_float)
      |> result.replace_error("Invalid score given"),
    )

    use score_maximum <- result.try(
      require_form_field(formdata, "score_maximum")
      |> result.then(parse_as_float)
      |> result.replace_error("Invalid score maximum"),
    )

    use comment <- result.try(require_form_field(formdata, "comment"))

    use user_id <- result.try(require_form_field(formdata, "user_id"))

    use registration <- result.try(
      require_form_field(formdata, "registration_id")
      |> result.then(fn(value) {
        int.parse(value)
        |> result.replace_error("Invalid registration_id")
      })
      |> result.then(fn(id) {
        registrations.get(app.db, id)
        |> result.replace_error("Error fetching registration")
      })
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

    use line_items_service_url <- result.try(
      list.key_find(formdata.values, "line_items_service_url")
      |> result.replace_error("Missing line_items_service_url"),
    )

    case
      ags.fetch_or_create_line_item(
        app.providers.http,
        line_items_service_url,
        line_item_id,
        fn() { 1.0 },
        line_item_name,
        access_token,
      )
    {
      Ok(line_item) -> {
        ags.post_score(app.providers.http, score, line_item, access_token)
      }
      Error(e) -> {
        logger.error_meta("Error fetching or creating line item", e)
        Error("Error fetching or creating line item: " <> string.inspect(e))
      }
    }
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

pub fn fetch_memberships(req: Request, app: AppContext) -> Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use context_memberships_url <- result.try(
      require_form_field(formdata, "context_memberships_url")
      |> result.replace_error("Missing context_memberships_url"),
    )

    use registration <- result.try(
      require_form_field(formdata, "registration_id")
      |> result.then(fn(value) {
        int.parse(value)
        |> result.replace_error("Invalid registration_id")
      })
      |> result.then(fn(id) {
        registrations.get(app.db, id)
        |> result.replace_error("Error fetching registration")
      })
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
