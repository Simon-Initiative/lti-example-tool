import gleam/http.{Get}
import lti_example_tool/html.{render_html} as _
import lti_example_tool/html/index_html
import lti_example_tool/web
import wisp.{type Request, type Response}

pub fn index(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let url = web.url()

  render_html(index_html.index(url))
}
