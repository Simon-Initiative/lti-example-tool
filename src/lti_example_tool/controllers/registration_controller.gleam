import gleam/http.{Get, Post}
import gleam/int
import gleam/list
import gleam/result
import lti/deployment.{Deployment}
import lti/registration.{Registration}
import lti/services/access_token
import lti/services/ags
import lti/services/nrps
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/database.{Record}
import lti_example_tool/deployments
import lti_example_tool/html.{render_html} as _
import lti_example_tool/html/components/page.{error_page}
import lti_example_tool/html/registrations_html
import lti_example_tool/registrations
import lti_example_tool/utils/common.{try_with} as _
import lti_example_tool/utils/logger
import wisp.{type Request, type Response}

pub fn resources(req: Request, app: AppContext) -> Response {
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
  use registrations <- try_with(registrations.all(app.db), or_else: fn(_) {
    wisp.log_error("Failed to fetch registrations")
    wisp.internal_server_error()
  })

  render_html(registrations_html.index(registrations))
}

pub fn show(req: Request, app: AppContext, registration_id: String) -> Response {
  use <- wisp.require_method(req, Get)

  use id <- try_with(int.parse(registration_id), or_else: fn(_) {
    wisp.log_error("Invalid registration ID")
    wisp.bad_request()
  })

  use Record(data: registration, ..) <- try_with(
    registrations.get(app.db, id),
    or_else: fn(_) { wisp.not_found() },
  )

  render_html(registrations_html.show(registration_id, registration))
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

  use id <- try_with(int.parse(id), or_else: fn(_) {
    wisp.log_error("Invalid registration ID")
    wisp.bad_request()
  })

  use _ <- try_with(registrations.delete(app.db, id), or_else: fn(_) {
    wisp.not_found()
  })

  wisp.redirect("/registrations")
}

pub fn access_token(
  req: Request,
  app: AppContext,
  registration_id: String,
) -> Response {
  use <- wisp.require_method(req, Post)

  use registration <- try_with(
    int.parse(registration_id)
      |> result.then(fn(id) {
        registrations.get(app.db, id) |> result.replace_error(Nil)
      })
      |> result.map(fn(record) { record.data }),
    or_else: fn(e) {
      logger.error_meta("Invalid registration ID", e)

      render_html(error_page("Something went wrong"))
    },
  )

  let result =
    access_token.fetch_access_token(app.providers, registration, [
      ags.lineitem_scope_url,
      ags.result_readonly_scope_url,
      ags.scores_scope_url,
      nrps.context_membership_readonly_claim_url,
    ])

  case result {
    Ok(access_token) -> {
      render_html(registrations_html.access_token(
        registration_id,
        access_token,
        registration,
      ))
    }
    Error(error_msg) -> {
      render_html(error_page(error_msg))
    }
  }
}
