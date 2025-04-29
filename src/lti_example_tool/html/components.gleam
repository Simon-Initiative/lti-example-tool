import lustre/attribute.{type Attribute, class}
import lustre/element.{type Element}
import lustre/element/html.{div}

pub fn card(attrs: List(Attribute(msg)), children: List(Element(msg))) {
  div(
    [
      class(
        "w-full max-w-sm p-4 bg-white border border-gray-200 rounded-lg shadow-sm sm:p-6 md:p-8 dark:bg-gray-800 dark:border-gray-700",
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
  LinkDanger
}

fn variant_class(variant: Variant) {
  case variant {
    Primary ->
      "text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 mb-2 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"
    Secondary ->
      "text-gray-900 bg-white border border-gray-300 hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm px-5 py-2.5 mb-2 dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700"
    Success ->
      "text-white bg-green-700 hover:bg-green-800 focus:ring-4 focus:ring-green-300 font-medium rounded-lg text-sm px-5 py-2.5 mb-2 dark:bg-green-600 dark:hover:bg-green-700 focus:outline-none dark:focus:ring-green-800"
    Danger ->
      "text-white bg-red-700 hover:bg-red-800 focus:ring-4 focus:ring-red-300 font-medium rounded-lg text-sm px-5 py-2.5 mb-2 dark:bg-red-600 dark:hover:bg-red-700 focus:outline-none dark:focus:ring-red-800"
    Warning ->
      "text-white bg-yellow-700 hover:bg-yellow-800 focus:ring-4 focus:ring-yellow-300 font-medium rounded-lg text-sm px-5 py-2.5 mb-2 dark:bg-yellow-600 dark:hover:bg-yellow-700 focus:outline-none dark:focus:ring-yellow-800"
    Info ->
      "text-white bg-blueGray hover:bg-blueGray-dark focus:ring-blueGray-light font-medium rounded-lg text-sm px-5 py-2.5 mb-2"
    Link ->
      "text-blue-600 hover:text-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 mb-2 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"
    LinkDanger ->
      "text-red-600 hover:text-red-800 focus:ring-4 focus:ring-red-300 font-medium rounded-lg text-sm px-5 py-2.5 mb-2 dark:bg-red-600 dark:hover:bg-red-700 focus:outline-none dark:focus:ring-red-800"
  }
}

pub fn button(
  variant: Variant,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) {
  html.button([class(variant_class(variant)), ..attrs], children)
}

pub fn link(
  variant: Variant,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) {
  html.a([class(variant_class(variant)), ..attrs], children)
}
