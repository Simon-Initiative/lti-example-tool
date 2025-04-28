import gleam/http.{Get, Post}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import lti/data_provider
import lti/deployment.{Deployment}
import lti/registration.{Registration}
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/platforms
import lti_example_tool/utils/common.{try_with}
import lti_example_tool/utils/html.{render_page} as _
import lustre/attribute
import lustre/element/html.{div, form, h1, input, label, text}
import wisp.{type Request, type Response}

pub fn resources(req: Request, app: AppContext) -> Response {
  // This handler for `/platforms` can respond to both GET and POST requests,
  // so we pattern match on the method here.
  case req.method, wisp.path_segments(req) {
    Get, ["platforms"] -> index(app)
    Post, ["platforms"] -> create(req, app)

    Get, ["platforms", "new"] -> new()

    Get, ["platforms", id] -> show(req, app, id)

    _, _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn index(app: AppContext) -> Response {
  let assert Ok(platforms) = platforms.all(app.db)

  let html =
    string_tree.from_string("Platforms" <> "\n" <> string.inspect(platforms))

  wisp.ok()
  |> wisp.html_body(html)
}

pub fn new() -> Response {
  render_page("Create Platform", [
    h1([], [text("Create Platform")]),
    form([attribute.method("post"), attribute.action("/platforms")], [
      div([], [
        label([], [
          text("Name: "),
          input([attribute.type_("text"), attribute.name("name")]),
        ]),
        label([], [
          text("Issuer: "),
          input([attribute.type_("text"), attribute.name("issuer")]),
        ]),
        label([], [
          text("Client ID: "),
          input([attribute.type_("text"), attribute.name("client_id")]),
        ]),
        label([], [
          text("Auth Endpoint: "),
          input([attribute.type_("text"), attribute.name("auth_endpoint")]),
        ]),
        label([], [
          text("Access Token Endpoint: "),
          input([
            attribute.type_("text"),
            attribute.name("access_token_endpoint"),
          ]),
        ]),
        label([], [
          text("Keyset URL: "),
          input([attribute.type_("text"), attribute.name("keyset_url")]),
        ]),
        label([], [
          text("Deployment ID: "),
          input([attribute.type_("text"), attribute.name("deployment_id")]),
        ]),
        input([attribute.type_("submit"), attribute.value("Submit")]),
      ]),
    ]),
  ])
}

pub fn create(req: Request, app: AppContext) -> Response {
  use formdata <- wisp.require_form(req)

  // The list and result module are used here to extract the values from the
  // form data.
  // Alternatively you could also pattern match on the list of values (they are
  // sorted into alphabetical order), or use a HTML form library.
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

    use #(registration_id, _registration) <- result.try(
      data_provider.create_registration(
        app.lti_data_provider,
        Registration(
          name,
          issuer,
          client_id,
          auth_endpoint,
          access_token_endpoint,
          keyset_url,
        ),
      ),
    )

    use _deployment <- result.try(data_provider.create_deployment(
      app.lti_data_provider,
      Deployment(deployment_id, registration_id),
    ))

    Ok(registration_id)
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

  let assert Ok(platforms) = platforms.get(app.db, id)

  let html =
    string_tree.from_string("Platforms" <> "\n" <> string.inspect(platforms))

  wisp.ok()
  |> wisp.html_body(html)
}
