import envoy
import gleam/int
import gleam/result
import gleam/string
import lti_example_tool/env.{type Env, Dev, Prod, Test}
import lti_example_tool/utils/logger

pub fn env() -> Env {
  let env =
    envoy.get("ENV")
    |> result.map(string.trim)
    |> result.map(string.lowercase)

  case env {
    Ok("dev") -> Dev
    Ok("test") -> Test
    Ok("prod") -> Prod
    _ -> Dev
  }
}

pub fn scheme() -> String {
  case envoy.get("SCHEME") {
    Ok(scheme) -> scheme
    Error(_) -> "http"
  }
}

pub fn port() -> Int {
  envoy.get("PORT")
  |> result.then(int.parse)
  |> result.unwrap(8080)
}

pub fn host() -> String {
  case envoy.get("HOST") {
    Ok(host) -> host
    Error(_) -> "localhost"
  }
}

pub fn secret_key_base(env: Env) -> String {
  case envoy.get("SECRET_KEY_BASE") {
    Ok(secret_key_base) -> secret_key_base
    Error(_) -> {
      env.exec(env, Prod, fn() {
        logger.warn(
          "SECRET_KEY_BASE is not set, using default which is not secure. "
          <> "You appear to be running in production, please set this environment variable.",
        )
      })

      "change_me"
    }
  }
}

pub fn db_name() -> String {
  case envoy.get("DB_NAME") {
    Ok(db_name) -> db_name
    Error(_) -> "lti_example_tool"
  }
}

pub fn database_url() -> String {
  case envoy.get("DATABASE_URL") {
    Ok(url) -> url
    Error(_) -> "postgresql://postgres:postgres@localhost:5432/lti_example_tool"
  }
}

pub fn env_var(name: String, default: String) {
  case envoy.get(name) {
    Ok(value) -> value
    Error(_) -> default
  }
}
