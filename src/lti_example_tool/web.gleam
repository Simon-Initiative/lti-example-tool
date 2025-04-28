import envoy
import gleam/int
import gleam/result
import lti/data_provider
import lti/deployment.{Deployment}
import lti/providers/memory_provider
import lti/registration.{Registration}
import lti_example_tool/app_context.{type AppContext, AppContext}
import lti_example_tool/database
import lti_example_tool/utils/logger
import wisp

pub fn setup() -> AppContext {
  let secret_key_base = load_secret_key_base()

  let db = database.connect("lti_example_tool")

  let assert Ok(lti_data_provider) = memory_provider.start()

  // TODO: REMOVE
  // Create a temporary registration and deployment
  let assert Ok(#(registration_id, _registration)) =
    data_provider.create_registration(
      lti_data_provider,
      Registration(
        name: "Example Registration",
        issuer: "http://localhost",
        client_id: "EXAMPLE_CLIENT_ID",
        auth_endpoint: "http://localhost/lti/authorize_redirect",
        access_token_endpoint: "http://localhost/auth/token",
        keyset_url: "http://localhost/.well-known/jwks.json",
      ),
    )

  let assert Ok(_deployment) =
    data_provider.create_deployment(
      lti_data_provider,
      Deployment(
        deployment_id: "7ad727c9-3f14-4ffc-91e5-8e1f0df27359",
        registration_id: registration_id,
      ),
    )

  let assert Ok(#(registration_id, _registration)) =
    data_provider.create_registration(
      lti_data_provider,
      Registration(
        name: "Canvas Registration",
        issuer: "https://canvas.oli.cmu.edu",
        client_id: "10000000000062",
        auth_endpoint: "https://canvas.oli.cmu.edu/api/lti/authorize_redirect",
        access_token_endpoint: "https://canvas.oli.cmu.edu/login/oauth2/token",
        keyset_url: "https://canvas.oli.cmu.edu/api/lti/security/jwks",
      ),
    )

  let assert Ok(_deployment) =
    data_provider.create_deployment(
      lti_data_provider,
      Deployment(
        deployment_id: "130:8865aa05b4b79b64a91a86042e43af5ea8ae79eb",
        registration_id: registration_id,
      ),
    )

  AppContext(
    port: load_port(),
    secret_key_base: secret_key_base,
    db: db,
    static_directory: static_directory(),
    lti_data_provider: lti_data_provider,
  )
}

pub fn middleware(
  req: wisp.Request,
  ctx: AppContext,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- made_with_gleam(req)
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)

  handle_request(req)
}

fn made_with_gleam(req, cb) -> wisp.Response {
  cb(req)
  |> wisp.set_header("made-with", "Gleam")
}

fn load_port() -> Int {
  envoy.get("PORT")
  |> result.then(int.parse)
  |> result.unwrap(3000)
}

fn load_secret_key_base() -> String {
  case envoy.get("SECRET_KEY_BASE") {
    Ok(secret_key_base) -> secret_key_base
    Error(_) -> {
      logger.warn(
        "SECRET_KEY_BASE is not set, using default which is not secure. "
        <> "If you are running in production, please set this environment variable.",
      )

      "change_me"
    }
  }
}

pub fn static_directory() -> String {
  // The priv directory is where we store non-Gleam and non-Erlang files,
  // including static assets to be served.
  // This function returns an absolute path and works both in development and in
  // production after compilation.
  let assert Ok(priv_directory) = wisp.priv_directory("lti_example_tool")

  priv_directory <> "/static"
}
