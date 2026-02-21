import nakai
import nakai/html.{type Node}
import wisp

pub fn render_html(el: Node) {
  wisp.ok()
  |> wisp.html_body(nakai.to_string(el))
}

pub fn render_html_status(el: Node, status: Int) {
  wisp.html_response(nakai.to_string(el), status)
}
