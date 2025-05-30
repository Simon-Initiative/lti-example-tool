import gleam/list
import nakai/attr.{type Attr, Attr, class}
import nakai/html.{type Node, div}

pub fn card(attrs: List(Attr), children: List(Node)) {
  div(
    [
      merge_classes(
        "w-full max-w-sm p-4 bg-white border border-gray-200 rounded-lg shadow-sm sm:p-6 md:p-8 dark:bg-gray-800 dark:border-gray-700",
        attrs,
      ),
      ..attrs
    ],
    children,
  )
}

pub type Variant {
  Primary
  Secondary
  Success
  Danger
  Warning
  Info
  Link
  DangerLink
}

fn variant_class(variant: Variant) {
  case variant {
    Primary ->
      "text-white bg-gray-800 hover:bg-gray-900 focus:ring-4 focus:ring-gray-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-gray-500 dark:hover:bg-gray-600 focus:outline-none dark:focus:ring-gray-700"
    Secondary ->
      "py-2.5 px-5 me-2 mb-2 text-sm font-medium text-gray-900 focus:outline-none bg-white rounded-lg border border-gray-200 hover:bg-gray-100 hover:text-gray-700 focus:z-10 focus:ring-4 focus:ring-gray-100 dark:focus:ring-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:text-white dark:hover:bg-gray-700"
    Success ->
      "focus:outline-none text-white bg-green-700 hover:bg-green-800 focus:ring-4 focus:ring-green-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-green-600 dark:hover:bg-green-700 dark:focus:ring-green-800"
    Danger ->
      "focus:outline-none text-white bg-red-700 hover:bg-red-800 focus:ring-4 focus:ring-red-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-900"
    Warning ->
      "focus:outline-none text-white bg-yellow-400 hover:bg-yellow-500 focus:ring-4 focus:ring-yellow-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:focus:ring-yellow-900"
    Info ->
      "focus:outline-none text-white bg-purple-700 hover:bg-purple-800 focus:ring-4 focus:ring-purple-300 font-medium rounded-lg text-sm px-5 py-2.5 mb-2 dark:bg-purple-600 dark:hover:bg-purple-700 dark:focus:ring-purple-900"
    Link ->
      "text-blue-600 hover:text-blue-700 focus:outline-none font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:text-blue-500 dark:hover:text-blue-400"
    DangerLink ->
      "text-red-600 hover:text-red-700 focus:outline-none font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:text-red-500 dark:hover:text-red-400"
  }
}

pub fn button(variant: Variant, attrs: List(Attr), children: List(Node)) {
  html.button([merge_classes(variant_class(variant), attrs), ..attrs], children)
}

pub fn link(variant: Variant, attrs: List(Attr), children: List(Node)) {
  html.a([merge_classes(variant_class(variant), attrs), ..attrs], children)
}

/// HELPER FUNCTIONS
fn merge_classes(classnames: String, attrs: List(Attr)) {
  case list.find(attrs, fn(a) { a.name == "class" }) {
    Ok(Attr(_, c)) -> class(c <> " " <> classnames)
    Error(Nil) -> class(classnames)
  }
}
