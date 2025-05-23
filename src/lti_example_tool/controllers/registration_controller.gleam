import gleam/http.{Get, Post}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lightbulb/deployment.{Deployment}
import lightbulb/registration.{Registration}
import lightbulb/services/access_token
import lightbulb/services/ags
import lightbulb/services/nrps
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/database.{Record}
import lti_example_tool/deployments
import lti_example_tool/feature_flags
import lti_example_tool/html.{render_html} as _
import lti_example_tool/html/components/page.{error_page}
import lti_example_tool/html/registrations_html
import lti_example_tool/registrations
import lti_example_tool/utils/logger
import lti_example_tool/web.{require_feature_flag}
import wisp.{type Request, type Response}

pub fn resources(req: Request, app: AppContext) -> Response {
  use <- require_feature_flag(app, feature_flags.Registrations)

  // This handler for `/registrations` can respond to both GET and POST requests,
  // so we pattern match on the method here.
  case req.method, wisp.path_segments(req) {
    Get, ["registrations"] -> index(app)
    Post, ["registrations"] -> create(req, app)

    Get, ["registrations", "new"] -> new()

    Get, ["registrations", id] -> show(req, app, id)

    Post, ["registrations", id, "delete"] -> delete(req, app, id)

    Post, ["registrations", id, "access_token"] -> access_token(req, app, id)

    _, _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn index(app: AppContext) -> Response {
  case registrations.all(app.db) {
    Ok(registrations) -> {
      render_html(registrations_html.index(registrations))
    }
    Error(e) -> {
      logger.error_meta("Failed to fetch registrations", e)

      render_html(error_page("Something went wrong"))
    }
  }
}

pub fn show(req: Request, app: AppContext, registration_id: String) -> Response {
  use <- wisp.require_method(req, Get)

  let record_result = {
    use id <- result.try(
      int.parse(registration_id)
      |> result.replace_error("Invalid registration ID"),
    )

    registrations.get(app.db, id)
    |> result.replace_error("Registration not found")
  }

  case record_result {
    Ok(Record(data: registration, ..)) -> {
      render_html(registrations_html.show(registration_id, registration))
    }
    Error(_error_msg) -> {
      wisp.not_found()
    }
  }
}

pub fn new() -> Response {
  render_html(registrations_html.new())
}

pub fn create(req: Request, app: AppContext) -> Response {
  use formdata <- wisp.require_form(req)

  let result = {
    use name <- result.try(list.key_find(formdata.values, "name"))
    use issuer <- result.try(list.key_find(formdata.values, "issuer"))
    use client_id <- result.try(list.key_find(formdata.values, "client_id"))
    use auth_endpoint <- result.try(list.key_find(
      formdata.values,
      "auth_endpoint",
    ))
    use access_token_endpoint <- result.try(list.key_find(
      formdata.values,
      "access_token_endpoint",
    ))
    use keyset_url <- result.try(list.key_find(formdata.values, "keyset_url"))
    use deployment_id <- result.try(list.key_find(
      formdata.values,
      "deployment_id",
    ))

    use registration_id <- result.try(
      registrations.insert(
        app.db,
        Registration(
          name,
          issuer,
          client_id,
          auth_endpoint,
          access_token_endpoint,
          keyset_url,
        ),
      )
      |> result.replace_error(Nil),
    )

    use _deployment_id <- result.try(
      deployments.insert(app.db, Deployment(deployment_id, registration_id))
      |> result.replace_error(Nil),
    )

    Ok(registration_id)
  }

  case result {
    Ok(registration_id) -> {
      wisp.redirect("/registrations/" <> int.to_string(registration_id))
    }
    Error(_) -> {
      wisp.bad_request()
    }
  }
}

pub fn delete(req: Request, app: AppContext, id: String) -> Response {
  use <- wisp.require_method(req, Post)

  let result = {
    use id <- result.try(
      int.parse(id) |> result.replace_error("Invalid registration ID"),
    )

    registrations.delete(app.db, id)
    |> result.map_error(fn(e) {
      "Failed to delete registration" <> string.inspect(e)
    })
  }

  case result {
    Ok(_) -> wisp.redirect("/registrations")
    Error(error_msg) -> {
      logger.error_meta("Failed to delete registration", error_msg)

      render_html(error_page("Something went wrong"))
    }
  }
}

pub fn access_token(
  req: Request,
  app: AppContext,
  registration_id: String,
) -> Response {
  use <- wisp.require_method(req, Post)

  let result = {
    use registration <- result.try(
      int.parse(registration_id)
      |> result.replace_error("Invalid registration ID")
      |> result.then(fn(id) {
        registrations.get(app.db, id)
        |> result.replace_error("Registration not found")
      })
      |> result.map(fn(record) { record.data }),
    )

    use access_token <- result.try(
      access_token.fetch_access_token(app.providers, registration, [
        ags.lineitem_scope_url,
        ags.result_readonly_scope_url,
        ags.scores_scope_url,
        nrps.context_membership_readonly_claim_url,
      ]),
    )

    Ok(#(registration, access_token))
  }

  case result {
    Ok(#(registration, access_token)) -> {
      render_html(registrations_html.access_token(
        registration_id,
        access_token,
        registration,
      ))
    }
    Error(error_msg) -> {
      logger.error_meta("Failed to fetch access token", error_msg)

      render_html(error_page("Failed to fetch access token: " <> error_msg))
    }
  }
}
