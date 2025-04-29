import envoy
import gleam/int
import gleam/result
import gleam/string
import lti_example_tool/app_context.{type AppContext, type Env, AppContext}
import lti_example_tool/database
import lti_example_tool/db_provider
import lti_example_tool/utils/devtools
import lti_example_tool/utils/logger
import wisp

pub fn setup() -> AppContext {
  let env = load_env()
  let secret_key_base = load_secret_key_base()

  let db = database.connect("lti_example_tool")

  let assert Ok(lti_data_provider) = db_provider.data_provider(db)

  let _ = devtools.maybe_start_devtools(env)

  AppContext(
    env: load_env(),
    port: load_port(),
    secret_key_base: secret_key_base,
    db: db,
    static_directory: static_directory(),
    lti_data_provider: lti_data_provider,
  )
}

fn load_env() -> Env {
  let env =
    envoy.get("ENV")
    |> result.map(string.trim)
    |> result.map(string.lowercase)

  case env {
    Ok("dev") -> app_context.Dev
    Ok("test") -> app_context.Test
    Ok("prod") -> app_context.Prod
    _ -> app_context.Dev
  }
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
