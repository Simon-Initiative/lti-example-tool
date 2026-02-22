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

pub fn port() -> Int {
  envoy.get("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
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

/// Returns the full public URL for the tool, including the scheme, host, and port.
pub fn public_url() {
  case envoy.get("PUBLIC_URL") {
    Ok(url) -> url
    Error(_) -> default_url()
  }
}

fn default_url() {
  case port() {
    80 -> "http://localhost"
    443 -> "https://localhost"
    port -> "http://localhost:" <> int.to_string(port)
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

pub fn bootstrap_token_ttl_seconds() -> Int {
  int_env_var("BOOTSTRAP_TOKEN_TTL_SECONDS", 300)
}

pub fn access_token_ttl_seconds() -> Int {
  int_env_var("ACCESS_TOKEN_TTL_SECONDS", 900)
}

pub fn refresh_token_ttl_seconds() -> Int {
  int_env_var("REFRESH_TOKEN_TTL_SECONDS", 86_400)
}

fn int_env_var(name: String, default: Int) -> Int {
  envoy.get(name)
  |> result.try(int.parse)
  |> result.unwrap(default)
}
