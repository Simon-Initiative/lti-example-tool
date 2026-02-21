import nakai/attr.{type Attr, class, type_, value}
import nakai/html.{type Node}

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
  default: String,
) -> Node {
  html.label(
    [class("block mb-2 text-sm font-medium text-gray-900 dark:text-white")],
    [
      html.Text(label),
      html.input([
        class(
          "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500",
        ),
        input_type_attr(input_type),
        attr.name(name),
        value(default),
      ]),
    ],
  )
}

fn input_type_attr(input_type: InputType) -> Attr {
  case input_type {
    Text -> "text"
    Email -> "email"
    Password -> "password"
    Number -> "number"
  }
  |> type_()
}
