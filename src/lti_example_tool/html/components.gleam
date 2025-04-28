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
