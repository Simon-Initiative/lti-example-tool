import gleam/http/response
import gleam/list
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import lti/deployment.{Deployment}
import lti/providers
import lti/providers/http_mock_provider
import lti/providers/memory_provider
import lti/registration.{Registration}
import lti_example_tool/app_context.{AppContext}
import lti_example_tool/config
import lti_example_tool/env
import lti_example_tool/router
import pog
import wisp/testing

pub fn main() {
  gleeunit.main()
}

fn test_db() {
  config.database_url()
  |> pog.url_config()
  |> result.map(fn(db_config) {
    pog.connect(
      pog.Config(..db_config, database: db_config.database <> "_test"),
    )
  })
}

fn setup() {
  let assert Ok(db) = test_db()
  let assert Ok(memory_provider) = memory_provider.start()
  let assert Ok(lti_data_provider) =
    memory_provider.data_provider(memory_provider)

  let http_provider =
    http_mock_provider.http_provider(fn(_req) {
      response.new(200)
      |> Ok
    })

  #(
    memory_provider,
    AppContext(
      env: env.Test,
      port: 8080,
      secret_key_base: "secret_key_base",
      db: db,
      static_directory: "static_directory",
      providers: providers.Providers(lti_data_provider, http_provider),
      feature_flags: [],
    ),
  )
}

pub fn get_home_page_test() {
  let #(_memory_provider, ctx) = setup()

  let request = testing.get("/", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(303)

  response.headers
  |> list.contains(#("location", "/registrations"))
  |> should.be_true

  response.headers
  |> list.contains(#("made-with", "Gleam"))
  |> should.be_true
}

pub fn login_test() {
  let #(memory_provider, ctx) = setup()

  let assert Ok(#(registration_id, registration)) =
    memory_provider.create_registration(
      memory_provider,
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
    memory_provider.create_deployment(
      memory_provider,
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
  let response = router.handle_request(request, ctx)

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
            "Max-Age=86400; Path=/; Secure; HttpOnly; SameSite=None",
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
  let #(_memory_provider, ctx) = setup()

  let request = testing.post("/", [], "a body")
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(405)
}

pub fn page_not_found_test() {
  let #(_memory_provider, ctx) = setup()

  let request = testing.get("/nothing-here", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(404)
}

pub fn get_registrations_test() {
  let #(_memory_provider, ctx) = setup()

  let request = testing.get("/registrations", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(200)
}

pub fn get_registration_test() {
  let #(_memory_provider, ctx) = setup()

  let request = testing.get("/registrations/123", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(404)
}
