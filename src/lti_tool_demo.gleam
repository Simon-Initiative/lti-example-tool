import gleam/erlang/process
import lti_tool_demo/router
import lti_tool_demo/web
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let ctx = web.setup()

  let assert Ok(_) =
    wisp_mist.handler(router.handle_request(_, ctx), secret_key_base)
    |> mist.new
    |> mist.port(ctx.port)
    |> mist.start_http

  process.sleep_forever()
}
