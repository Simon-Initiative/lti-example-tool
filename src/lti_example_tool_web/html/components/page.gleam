import nakai/attr.{charset, class, content, crossorigin, href, lang, name, rel}
import nakai/html.{type Node, div, h1_text, link, meta, p_text, title}

pub fn page(title page_title: String, content page_content: List(Node)) -> Node {
  html.Html([lang("en")], [
    html.Head([
      title(page_title),
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
        attr.Attr("referrerpolicy", "no-referrer"),
      ]),
    ]),
    html.Body(
      [
        class(
          "bg-primary dark:bg-gray-900 dark:text-white flex flex-col h-screen",
        ),
      ],
      [
        div([class("flex-1 flex flex-row")], [
          div([class("flex-1 my-6 px-3")], [
            h1_text(
              [class("max-w-sm mx-auto text-2xl text-center mb-4")],
              page_title,
            ),
            ..page_content
          ]),
        ]),
      ],
    ),
  ])
}

pub fn error_page(error_message: String) {
  page("An Error Occurred", [
    div([class("text-center")], [p_text([class("text-red-500")], error_message)]),
  ])
}
