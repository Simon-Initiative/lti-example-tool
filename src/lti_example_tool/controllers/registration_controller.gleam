import gleam/http.{Get, Post}
import gleam/int
import gleam/list
import gleam/result
import lti/deployment.{Deployment}
import lti/registration.{type Registration, Registration}
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/database.{type Record, Record}
import lti_example_tool/deployments
import lti_example_tool/html.{render_page} as _
import lti_example_tool/html/components.{DangerLink, Link, Primary, Secondary}
import lti_example_tool/html/forms
import lti_example_tool/html/tables.{Column}
import lti_example_tool/registrations
import lti_example_tool/utils/common.{try_with} as _
import lustre/attribute.{action, class, href, method, type_}
import lustre/element/html.{div, form, text}
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

    _, _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn index(app: AppContext) -> Response {
  use registrations <- try_with(registrations.all(app.db), or_else: fn(_) {
    wisp.log_error("Failed to fetch registrations")
    wisp.internal_server_error()
  })

  render_page("All Registrations", [
    div([class("flex flex-row justify-end mb-4")], [
      components.link(Primary, [href("/registrations/new")], [
        text("Register Platform"),
      ]),
    ]),
    tables.table(
      [],
      [
        Column("ID", fn(record: Record(Int, Registration)) {
          let Record(id, ..) = record
          text(int.to_string(id))
        }),
        Column("Name", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          text(registration.name)
        }),
        Column("Issuer", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          text(registration.issuer)
        }),
        Column("Client ID", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          text(registration.client_id)
        }),
        Column("Actions", fn(record: Record(Int, Registration)) {
          let Record(id, ..) = record
          div([], [
            components.link(
              Link,
              [href("/registrations/" <> int.to_string(id))],
              [text("View")],
            ),
          ])
        }),
      ],
      registrations,
    ),
  ])
}

pub fn new() -> Response {
  render_page("Register Platform", [
    components.card([class("max-w-sm mx-auto")], [
      form([method("post"), action("/registrations")], [
        div([class("flex flex-col")], [
          forms.labeled_input("Name", "name"),
          forms.labeled_input("Issuer", "issuer"),
          forms.labeled_input("Client ID", "client_id"),
          forms.labeled_input("Auth Endpoint", "auth_endpoint"),
          forms.labeled_input("Access Token Endpoint", "access_token_endpoint"),
          forms.labeled_input("Keyset URL", "keyset_url"),
          forms.labeled_input("Deployment ID", "deployment_id"),
          components.button(Primary, [class("my-8"), type_("submit")], [
            text("Register"),
          ]),
          components.link(
            Secondary,
            [class("my-2 text-center"), href("/registrations")],
            [text("Cancel")],
          ),
        ]),
      ]),
    ]),
  ])
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

pub fn show(req: Request, app: AppContext, id: String) -> Response {
  use <- wisp.require_method(req, Get)

  use id <- try_with(int.parse(id), or_else: fn(_) {
    wisp.log_error("Invalid registration ID")
    wisp.bad_request()
  })

  use Record(data: registration, ..) <- try_with(
    registrations.get(app.db, id),
    or_else: fn(_) { wisp.not_found() },
  )

  render_page("Platform Registration Details", [
    div([class("flex flex-col")], [
      div([class("text-2xl font-bold")], [text(registration.name)]),
      div([class("text-gray-500")], [text(registration.issuer)]),
      div([class("text-gray-500")], [text(registration.client_id)]),
      div([class("text-gray-500")], [text(registration.auth_endpoint)]),
      div([class("text-gray-500")], [text(registration.access_token_endpoint)]),
      div([class("text-gray-500")], [text(registration.keyset_url)]),
    ]),
    div([class("flex flex-row")], [
      components.link(Link, [href("/registrations")], [
        text("Back to Registrations"),
      ]),
      form(
        [
          method("post"),
          action("/registrations/" <> int.to_string(id) <> "/delete"),
        ],
        [
          div([class("flex flex-row")], [
            components.button(DangerLink, [class("ml-2"), type_("submit")], [
              text("Delete"),
            ]),
          ]),
        ],
      ),
    ]),
  ])
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
