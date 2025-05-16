import lustre/element
import lustre/vdom/vnode
import wisp

pub fn render_html(el: vnode.Element(a)) {
  wisp.ok()
  |> wisp.html_body(element.to_string_tree(el))
}
