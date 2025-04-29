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
import lti_example_tool/platforms
import lti_example_tool/utils/common.{try_with} as _
import lustre/attribute.{action, class, href, method, type_}
import lustre/element/html.{div, form, text}
import wisp.{type Request, type Response}

pub fn resources(req: Request, app: AppContext) -> Response {
  // This handler for `/platforms` can respond to both GET and POST requests,
  // so we pattern match on the method here.
  case req.method, wisp.path_segments(req) {
    Get, ["platforms"] -> index(app)
    Post, ["platforms"] -> create(req, app)

    Get, ["platforms", "new"] -> new()

    Get, ["platforms", id] -> show(req, app, id)

    Post, ["platforms", id, "delete"] -> delete(req, app, id)

    _, _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn index(app: AppContext) -> Response {
  use platforms <- try_with(platforms.all(app.db), or_else: fn(_) {
    wisp.log_error("Failed to fetch platforms")
    wisp.internal_server_error()
  })

  render_page("All Platforms", [
    div([class("flex flex-row justify-end mb-4")], [
      components.link(Primary, [href("/platforms/new")], [
        text("Register Platform"),
      ]),
    ]),
    tables.table(
      [],
      [
        Column("ID", fn(record: Record(Registration)) {
          let Record(id, ..) = record
          text(int.to_string(id))
        }),
        Column("Name", fn(record: Record(Registration)) {
          let Record(data: platform, ..) = record
          text(platform.name)
        }),
        Column("Issuer", fn(record: Record(Registration)) {
          let Record(data: platform, ..) = record
          text(platform.issuer)
        }),
        Column("Client ID", fn(record: Record(Registration)) {
          let Record(data: platform, ..) = record
          text(platform.client_id)
        }),
        Column("Actions", fn(record: Record(Registration)) {
          let Record(id, ..) = record
          div([], [
            components.link(Link, [href("/platforms/" <> int.to_string(id))], [
              text("View"),
            ]),
          ])
        }),
      ],
      platforms,
    ),
  ])
}

pub fn new() -> Response {
  render_page("Register Platform", [
    components.card([class("max-w-sm mx-auto")], [
      form([method("post"), action("/platforms")], [
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
            [class("my-2 text-center"), href("/platforms")],
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

    use platform_id <- result.try(
      platforms.insert(
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
      deployments.insert(app.db, Deployment(deployment_id, platform_id))
      |> result.replace_error(Nil),
    )

    Ok(platform_id)
  }

  case result {
    Ok(platform_id) -> {
      wisp.redirect("/platforms/" <> int.to_string(platform_id))
    }
    Error(_) -> {
      wisp.bad_request()
    }
  }
}

pub fn show(req: Request, app: AppContext, id: String) -> Response {
  use <- wisp.require_method(req, Get)

  use id <- try_with(int.parse(id), or_else: fn(_) {
    wisp.log_error("Invalid platform ID")
    wisp.bad_request()
  })

  use Record(data: platform, ..) <- try_with(
    platforms.get(app.db, id),
    or_else: fn(_) { wisp.not_found() },
  )

  render_page("Platform Platform Details", [
    div([class("flex flex-col")], [
      div([class("text-2xl font-bold")], [text(platform.name)]),
      div([class("text-gray-500")], [text(platform.issuer)]),
      div([class("text-gray-500")], [text(platform.client_id)]),
      div([class("text-gray-500")], [text(platform.auth_endpoint)]),
      div([class("text-gray-500")], [text(platform.access_token_endpoint)]),
      div([class("text-gray-500")], [text(platform.keyset_url)]),
    ]),
    div([class("flex flex-row")], [
      components.link(Link, [href("/platforms")], [text("Back to Platforms")]),
      form(
        [
          method("post"),
          action("/platforms/" <> int.to_string(id) <> "/delete"),
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
    wisp.log_error("Invalid platform ID")
    wisp.bad_request()
  })

  use _ <- try_with(platforms.delete(app.db, id), or_else: fn(_) {
    wisp.not_found()
  })

  wisp.redirect("/platforms")
}
