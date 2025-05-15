import gleam/list
import gleam/option.{type Option}
import lustre/attribute.{class}
import lustre/element/html
import lustre/vdom/vattr
import lustre/vdom/vnode

pub type InputType {
  Text
  Email
  Password
  Number
}

pub fn labeled_input(
  input_type: InputType,
  label: String,
  name: String,
  default: Option(String),
) -> vnode.Element(a) {
  html.label(
    [class("block mb-2 text-sm font-medium text-gray-900 dark:text-white")],
    [
      html.text(label),
      html.input(
        [
          class(
            "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500",
          ),
          input_type_attr(input_type),
          attribute.name(name),
        ]
        |> list.append(
          default
          |> option.map(fn(v) { [attribute.value(v)] })
          |> option.unwrap([]),
        ),
      ),
    ],
  )
}

fn input_type_attr(input_type: InputType) -> vattr.Attribute(a) {
  case input_type {
    Text -> "text"
    Email -> "email"
    Password -> "password"
    Number -> "number"
  }
  |> attribute.type_()
}
