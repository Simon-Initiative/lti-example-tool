import envoy
import gleam/int
import gleam/result
import lti/providers/memory_provider
import lti_example_tool/app_context.{type AppContext, AppContext}
import lti_example_tool/database
import lti_example_tool/seeds
import lti_example_tool/utils/logger
import wisp

pub fn setup() -> AppContext {
  let secret_key_base = load_secret_key_base()

  let db = database.connect("lti_example_tool")

  let assert Ok(lti_data_provider) = memory_provider.start()

  let assert Ok(_) = seeds.load(lti_data_provider)

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
