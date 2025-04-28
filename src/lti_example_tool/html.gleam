import lustre/attribute.{
  charset, class, content, crossorigin, href, lang, name, referrerpolicy, rel,
}
import lustre/element
import lustre/element/html.{body, div, h1, head, html, link, meta, text, title}
import lustre/vdom/vnode
import wisp

pub fn render_page(
  title page_title: String,
  body page_body: List(vnode.Element(a)),
) {
  let layout = page_layout(page_title)

  wisp.ok()
  |> wisp.html_body(
    layout(page_body)
    |> element.to_string_tree(),
  )
}

pub fn page_layout(page_title: String) {
  fn(inner_content: List(vnode.Element(a))) {
    html([lang("en")], [
      head([], [
        title([], page_title),
        meta([charset("utf-8")]),
        meta([name("viewport"), content("width=device-width, initial-scale=1")]),
        meta([name("description"), content("LTI Example Tool")]),
        link([rel("stylesheet"), href("/static/app.css")]),
        link([
          rel("stylesheet"),
          href(
            "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.2.1/css/all.min.css",
          ),
          crossorigin("anonymous"),
          referrerpolicy("no-referrer"),
        ]),
      ]),
      body(
        [
          class(
            "bg-primary dark:bg-gray-900 dark:text-white flex flex-col h-screen",
          ),
        ],
        [
          div([class("flex-1 flex flex-row")], [
            div([class("flex-1 my-6")], [
              h1([class("max-w-sm mx-auto text-xl mb-4")], [text(page_title)]),
              ..inner_content
            ]),
          ]),
        ],
      ),
    ])
  }
}
