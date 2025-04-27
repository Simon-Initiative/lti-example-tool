import gleam/option.{type Option}
import gleam/result
import kv_sessions
import kv_sessions/actor_adapter
import kv_sessions/session
import kv_sessions/session_config
import wisp.{type Request, type Response}

const session_cookie = "SESSION_COOKIE"

pub type SessionConfig =
  session_config.Config

pub type SessionError {
  SessionError
}

pub fn init() {
  // Setup session_adapter
  use store <- result.try(actor_adapter.new())
  use cache_store <- result.try(actor_adapter.new())

  // Create session config
  Ok(session_config.Config(
    default_expiry: session.ExpireIn(60 * 60),
    cookie_name: session_cookie,
    store: store,
    cache: option.Some(cache_store),
  ))
}

pub fn middleware(
  req: Request,
  session_config: session_config.Config,
  cb: fn(Request) -> Response,
) {
  kv_sessions.middleware(req, session_config, cb)
}

pub fn session(
  req: Request,
  session_config: SessionConfig,
  key: String,
  cb: fn(Option(String)) -> Response,
) -> Response {
  let current_session = kv_sessions.CurrentSession(req, session_config)

  let assert Ok(value) =
    current_session
    |> kv_sessions.key(key)
    |> kv_sessions.get()

  cb(value)
}

pub fn put_session(
  req: Request,
  session_config: SessionConfig,
  key: String,
  value: String,
) -> Result(String, SessionError) {
  let current_session = kv_sessions.CurrentSession(req, session_config)

  // Set value to the session
  let _ =
    current_session
    |> kv_sessions.key(key)
    |> kv_sessions.set(value)
    |> result.map_error(fn(_) { SessionError })
}
