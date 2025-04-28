import lti_example_tool/app_context.{type AppContext}
import wisp

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
