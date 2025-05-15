import gleam/erlang/process
import lti_example_tool/application
import lti_example_tool/router
import lti_example_tool/utils/logger
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  logger.configure_backend()
  wisp.configure_logger()

  let ctx = application.setup()

  let assert Ok(_) =
    router.handle_request(_, ctx)
    |> wisp_mist.handler(ctx.secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(ctx.port)
    |> mist.start_http

  process.sleep_forever()
}
