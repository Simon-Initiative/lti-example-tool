import gleam/int
import gleam/list
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/config
import lti_example_tool/feature_flags.{type FeatureFlags}
import lti_example_tool/utils/logger
import wisp.{type Response}

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

pub fn require_feature_flag(
  app: AppContext,
  feature: FeatureFlags,
  cb: fn() -> Response,
) -> Response {
  case list.find(app.feature_flags, fn(f) { f == feature }) {
    Ok(_) -> cb()
    Error(_) -> {
      logger.error_meta("Feature flag is disabled", feature)

      wisp.not_found()
    }
  }
}

/// Returns the full URL for the tool, including the scheme, host, and port.
pub fn url() {
  let scheme = config.scheme()
  let host = config.host()
  let port = config.port()

  case port == 80 || port == 443 {
    True -> scheme <> "://" <> host
    False -> scheme <> "://" <> host <> ":" <> int.to_string(port)
  }
}
