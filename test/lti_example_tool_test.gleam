import gleam/list
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import lti/data_provider
import lti/deployment.{Deployment}
import lti/providers/memory_provider
import lti/registration.{Registration}
import lti_example_tool/app_context.{AppContext}
import lti_example_tool/database
import lti_example_tool/router
import wisp/testing

pub fn main() {
  gleeunit.main()
}

fn app_context() {
  let assert Ok(lti_data_provider) = memory_provider.start()

  AppContext(
    port: 8080,
    secret_key_base: "secret_key_base",
    db: database.connect("lti_example_tool_test"),
    static_directory: "static_directory",
    lti_data_provider: lti_data_provider,
  )
}

pub fn get_home_page_test() {
  let request = testing.get("/", [])
  let response = router.handle_request(request, app_context())

  response.status
  |> should.equal(200)

  response.headers
  |> list.contains(#("content-type", "text/html; charset=utf-8"))
  |> should.be_true

  response.headers
  |> list.contains(#("made-with", "Gleam"))
  |> should.be_true

  response
  |> testing.string_body
  |> should.equal(
    "LTI Example Tool\nThis is an example web application that demonstrates how to build an LTI tool.",
  )
}

pub fn login_test() {
  let ctx = app_context()
  let AppContext(lti_data_provider: lti_data_provider, ..) = ctx

  let assert Ok(#(registration_id, registration)) =
    data_provider.create_registration(
      lti_data_provider,
      Registration(
        name: "Example Registration",
        issuer: "http://example.com",
        client_id: "SOME_CLIENT_ID",
        auth_endpoint: "http://example.com/lti/authorize_redirect",
        access_token_endpoint: "http://example.com/auth/token",
        keyset_url: "http://example.com/.well-known/jwks.json",
      ),
    )

  let assert Ok(_deployment) =
    data_provider.create_deployment(
      lti_data_provider,
      Deployment(
        deployment_id: "some-deployment-id",
        registration_id: registration_id,
      ),
    )

  let form_data = [
    #("client_id", registration.client_id),
    #("iss", registration.issuer),
    #("login_hint", "d9d4526d-3395-4f16-ba7f-242a9f1b9d20"),
    #("target_link_uri", "http://example.com/launch"),
  ]
  let request = testing.post_form("/login", [], form_data)
  let response = router.handle_request(request, app_context())

  response.status
  |> should.equal(303)

  response.headers
  |> list.find(fn(header) {
    case header {
      #("set-cookie", _) -> True
      _ -> False
    }
  })
  |> result.map(fn(header) {
    case header {
      #("set-cookie", cookie) -> {
        {
          string.contains(cookie, "state=")
          && string.contains(
            cookie,
            "Max-Age=3599; Path=/; Secure; HttpOnly; SameSite=None",
          )
        }
        |> should.be_true
      }
      _ -> Nil
    }
  })
  |> should.be_ok
}

pub fn post_home_page_test() {
  let request = testing.post("/", [], "a body")
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(405)
}

pub fn page_not_found_test() {
  let request = testing.get("/nothing-here", [])
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(404)
}

pub fn get_platforms_test() {
  let request = testing.get("/platforms", [])
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(200)
}

// pub fn post_platforms_test() {
//   let request = testing.post("/platforms", [], "")
//   let response = router.handle_request(request, app_context())
//   response.status
//   |> should.equal(201)
// }

pub fn delete_platforms_test() {
  let request = testing.delete("/platforms", [], "")
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(405)
}

pub fn get_platform_test() {
  let request = testing.get("/platforms/123", [])
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(200)
  response
  |> testing.string_body
  |> should.equal("Platforms\nNone")
}

pub fn delete_platform_test() {
  let request = testing.delete("/platforms/123", [], "")
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(405)
}
