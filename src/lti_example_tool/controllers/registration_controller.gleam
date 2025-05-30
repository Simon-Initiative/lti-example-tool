import formal/form.{Form}
import gleam/dict
import gleam/http.{Get, Post}
import gleam/int
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
import wisp.{type Request, type Response}

pub fn resources(req: Request, app: AppContext) -> Response {
  case
    feature_flags.feature_enabled(
      app.feature_flags,
      feature_flags.Registrations,
    )
  {
    True -> {
      // This handler for `/registrations` can respond to both GET and POST requests,
      // so we pattern match on the method here.
      case req.method, wisp.path_segments(req) {
        Get, ["registrations"] -> index(app)

        Get, ["registrations", "new"] -> new()

        Post, ["registrations"] -> create(req, app)

        Get, ["registrations", id] -> show(req, app, id)

        Get, ["registrations", id, "edit"] -> edit(req, app, id)

        Post, ["registrations", id] -> update(req, app, id)

        Post, ["registrations", id, "delete"] -> delete(req, app, id)

        Post, ["registrations", id, "access_token"] ->
          access_token(req, app, id)

        _, _ -> wisp.method_not_allowed([Get, Post])
      }
    }
    False -> {
      render_html(registrations_html.feature_not_enabled())
    }
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
  render_html(
    registrations_html.edit(
      "Register Platform",
      Form(dict.new(), dict.new()),
      #("Register", "/registrations"),
      #("Cancel", "/registrations"),
    ),
  )
}

type EditRegistrationForm {
  EditRegistrationForm(
    name: String,
    issuer: String,
    client_id: String,
    auth_endpoint: String,
    access_token_endpoint: String,
    keyset_url: String,
    deployment_id: String,
  )
}

pub fn create(req: Request, app: AppContext) -> Response {
  use formdata <- wisp.require_form(req)

  let registration_form =
    form.decoding({
      use name <- form.parameter
      use issuer <- form.parameter
      use client_id <- form.parameter
      use auth_endpoint <- form.parameter
      use access_token_endpoint <- form.parameter
      use keyset_url <- form.parameter
      use deployment_id <- form.parameter

      EditRegistrationForm(
        name,
        issuer,
        client_id,
        auth_endpoint,
        access_token_endpoint,
        keyset_url,
        deployment_id,
      )
    })
    |> form.with_values(formdata.values)
    |> form.field("name", form.string |> form.and(form.must_not_be_empty))
    |> form.field("issuer", form.string |> form.and(form.must_not_be_empty))
    |> form.field("client_id", form.string |> form.and(form.must_not_be_empty))
    |> form.field(
      "auth_endpoint",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.field(
      "access_token_endpoint",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.field("keyset_url", form.string |> form.and(form.must_not_be_empty))
    |> form.field(
      "deployment_id",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.finish()

  case registration_form {
    Ok(EditRegistrationForm(
      name,
      issuer,
      client_id,
      auth_endpoint,
      access_token_endpoint,
      keyset_url,
      deployment_id,
    )) -> {
      let result = {
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
          |> result.replace_error("Failed to create registration"),
        )

        use _deployment_id <- result.try(
          deployments.insert(app.db, Deployment(deployment_id, registration_id))
          |> result.replace_error("Failed to create deployment"),
        )

        Ok(registration_id)
      }

      case result {
        Ok(registration_id) -> {
          wisp.redirect("/registrations/" <> int.to_string(registration_id))
        }
        Error(error_msg) -> {
          logger.error_meta("Failed to create registration", error_msg)

          wisp.bad_request()
        }
      }
    }
    Error(invalid_form) -> {
      render_html(
        registrations_html.edit(
          "Register Platform",
          invalid_form,
          #("Register", "/registrations"),
          #("Cancel", "/registrations"),
        ),
      )
    }
  }
}

pub fn edit(req: Request, app: AppContext, registration_id: String) -> Response {
  use <- wisp.require_method(req, Get)

  let record_result = {
    use id <- result.try(
      int.parse(registration_id)
      |> result.replace_error("Invalid registration ID"),
    )

    use registration_record <- result.try(
      registrations.get(app.db, id)
      |> result.replace_error("Registration not found"),
    )

    use deployment_record <- result.try(
      deployments.get_single_deployment_by_registration_id(
        app.db,
        registration_record.id,
      )
      |> result.replace_error("Deployment not found"),
    )

    Ok(#(registration_record, deployment_record))
  }

  case record_result {
    Ok(#(Record(data: registration, ..), Record(data: deployment, ..))) -> {
      let registration_form =
        form.initial_values([
          #("name", registration.name),
          #("issuer", registration.issuer),
          #("client_id", registration.client_id),
          #("auth_endpoint", registration.auth_endpoint),
          #("access_token_endpoint", registration.access_token_endpoint),
          #("keyset_url", registration.keyset_url),
          #("deployment_id", deployment.deployment_id),
        ])

      render_html(
        registrations_html.edit(
          "Edit Platform Registration",
          registration_form,
          #("Update", "/registrations/" <> registration_id),
          #("Cancel", "/registrations/" <> registration_id),
        ),
      )
    }
    Error(error_msg) -> {
      logger.error_meta("Failed to fetch registration for editing", error_msg)

      render_html(error_page("Registration not found"))
    }
  }
}

pub fn update(
  req: Request,
  app: AppContext,
  registration_id: String,
) -> Response {
  use formdata <- wisp.require_form(req)

  let registration_form =
    form.decoding({
      use name <- form.parameter
      use issuer <- form.parameter
      use client_id <- form.parameter
      use auth_endpoint <- form.parameter
      use access_token_endpoint <- form.parameter
      use keyset_url <- form.parameter
      use deployment_id <- form.parameter

      EditRegistrationForm(
        name,
        issuer,
        client_id,
        auth_endpoint,
        access_token_endpoint,
        keyset_url,
        deployment_id,
      )
    })
    |> form.with_values(formdata.values)
    |> form.field("name", form.string |> form.and(form.must_not_be_empty))
    |> form.field("issuer", form.string |> form.and(form.must_not_be_empty))
    |> form.field("client_id", form.string |> form.and(form.must_not_be_empty))
    |> form.field(
      "auth_endpoint",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.field(
      "access_token_endpoint",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.field("keyset_url", form.string |> form.and(form.must_not_be_empty))
    |> form.field(
      "deployment_id",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.finish()

  case registration_form {
    Ok(EditRegistrationForm(
      name,
      issuer,
      client_id,
      auth_endpoint,
      access_token_endpoint,
      keyset_url,
      deployment_id,
    )) -> {
      let result = {
        use registration_record <- result.try(
          int.parse(registration_id)
          |> result.replace_error("Invalid registration ID")
          |> result.then(fn(id) {
            registrations.get(app.db, id)
            |> result.replace_error("Registration not found")
          }),
        )

        use _ <- result.try(
          registrations.update(
            app.db,
            Record(
              ..registration_record,
              id: registration_record.id,
              data: Registration(
                name: name,
                issuer: issuer,
                client_id: client_id,
                auth_endpoint: auth_endpoint,
                access_token_endpoint: access_token_endpoint,
                keyset_url: keyset_url,
              ),
            ),
          )
          |> echo
          |> result.replace_error("Failed to update registration"),
        )

        use deployment_record <- result.try(
          deployments.get_single_deployment_by_registration_id(
            app.db,
            registration_record.id,
          )
          |> result.replace_error("Deployment not found"),
        )

        use _deployment_id <- result.try(
          deployments.update(
            app.db,
            Record(
              ..deployment_record,
              data: Deployment(deployment_id, registration_record.id),
            ),
          )
          |> result.replace_error("Failed to update deployment"),
        )

        Ok(registration_id)
      }

      case result {
        Ok(registration_id) -> {
          wisp.redirect("/registrations/" <> registration_id)
        }
        Error(error_msg) -> {
          logger.error_meta("Failed to create registration", error_msg)

          wisp.bad_request()
        }
      }
    }
    Error(invalid_form) -> {
      render_html(
        registrations_html.edit(
          "Edit Platform Registration",
          invalid_form,
          #("Update", "/registrations/" <> registration_id),
          #("Cancel", "/registrations/" <> registration_id),
        ),
      )
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
