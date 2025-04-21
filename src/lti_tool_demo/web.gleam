import envoy
import gleam/int
import gleam/result
import lti/providers/memory_provider
import lti_tool_demo/app_context.{type AppContext, AppContext}
import lti_tool_demo/database
import lti_tool_demo/session
import wisp

pub fn setup() -> AppContext {
  let secret_key_base = load_secret_key_base()

  let db = database.connect("lti_tool_demo")

  // Setup session_adapter
  let assert Ok(session_config) = session.init()

  let assert Ok(lti_data_provider) = memory_provider.start()

  AppContext(
    port: load_port(),
    secret_key_base: secret_key_base,
    db: db,
    static_directory: static_directory(),
    session_config: session_config,
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
  use req <- session.middleware(req, ctx.session_config)

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
  envoy.get("SECRET_KEY_BASE")
  |> result.unwrap("change_me")
}

pub fn static_directory() -> String {
  // The priv directory is where we store non-Gleam and non-Erlang files,
  // including static assets to be served.
  // This function returns an absolute path and works both in development and in
  // production after compilation.
  let assert Ok(priv_directory) = wisp.priv_directory("lti_tool_demo")

  priv_directory <> "/static"
}
