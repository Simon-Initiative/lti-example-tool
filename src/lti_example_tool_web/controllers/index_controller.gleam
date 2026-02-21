import gleam/http.{Get}
import lti_example_tool/config
import lti_example_tool_web/html.{render_html} as _
import lti_example_tool_web/html/index_html
import wisp.{type Request, type Response}

pub fn index(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let public_url = config.public_url()

  render_html(index_html.index(public_url))
}
