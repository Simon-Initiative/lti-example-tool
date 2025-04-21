import gleam/erlang/process
import lti_tool_demo/router
import lti_tool_demo/utils/logger
import lti_tool_demo/web
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  logger.configure_backend()
  wisp.configure_logger()

  let ctx = web.setup()

  let assert Ok(_) =
    wisp_mist.handler(router.handle_request(_, ctx), ctx.secret_key_base)
    |> mist.new
    |> mist.port(ctx.port)
    |> mist.start_http

  process.sleep_forever()
}
