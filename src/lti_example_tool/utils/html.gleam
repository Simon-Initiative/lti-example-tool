import lustre/element
import lustre/element/html.{body, head, html, title}
import lustre/vdom/vnode
import wisp

pub fn render_page(
  title page_title: String,
  body page_body: List(vnode.Element(a)),
) {
  let html = html([], [head([], [title([], page_title)]), body([], page_body)])

  wisp.ok()
  |> wisp.html_body(
    html
    |> element.to_string_tree(),
  )
}
