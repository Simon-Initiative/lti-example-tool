import gleam/list
import lustre/attribute.{type Attribute, class}
import lustre/element.{type Element}
import lustre/element/html.{div, tbody, td, text, th, thead, tr}

pub type Column(msg, d) {
  Column(label: String, renderer: fn(d) -> Element(msg))
}

pub fn table(
  attrs: List(Attribute(msg)),
  columns: List(Column(msg, d)),
  data: List(d),
) -> Element(msg) {
  div([class("relative overflow-x-auto border border-gray-100")], [
    html.table([class("w-full text-sm text-left rtl:text-right"), ..attrs], [
      thead(
        [
          class(
            "text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400",
          ),
        ],
        [
          tr(
            [
              class(
                "border-b bg-gray-100 dark:bg-gray-800 dark:border-gray-700",
              ),
            ],
            list.map(columns, fn(c) {
              th(
                [
                  class(
                    "px-6 py-4 font-semibold text-gray-900 whitespace-nowrap dark:text-white",
                  ),
                ],
                [text(c.label)],
              )
            }),
          ),
        ],
      ),
      tbody(
        [],
        list.map(data, fn(d) {
          tr(
            [class("bg-white border-b dark:bg-gray-800 dark:border-gray-700")],
            list.map(columns, fn(c) {
              td([class("px-6 py-4 wrap-break-word")], [c.renderer(d)])
            }),
          )
        }),
      ),
    ]),
  ])
}
