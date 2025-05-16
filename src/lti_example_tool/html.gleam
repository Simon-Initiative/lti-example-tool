import nakai
import nakai/html.{type Node}
import wisp

pub fn render_html(el: Node) {
  wisp.ok()
  |> wisp.html_body(nakai.to_string_tree(el))
}
