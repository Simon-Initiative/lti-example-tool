import lti_example_tool_web/html/components
import lti_example_tool_web/html/components/forms
import lti_example_tool_web/html/components/page.{page}
import nakai/attr.{action, class, method, name, type_, value}
import nakai/html.{type Node, div, input, p}

pub fn sign_in(return_to: String, error_message: String) -> Node {
  page("Admin Sign In", [
    components.card([class("max-w-sm mx-auto")], [
      html.form([method("post"), action("/admin/auth")], [
        div([class("flex flex-col")], [
          forms.labeled_input(forms.Password, "Admin Password", "password", ""),
          input([type_("hidden"), name("return_to"), value(return_to)]),
          case error_message == "" {
            True -> html.Text("")
            False ->
              p([class("mt-2 text-sm text-red-600")], [html.Text(error_message)])
          },
          components.button(
            components.Primary,
            [class("my-8"), type_("submit")],
            [
              html.Text("Sign In"),
            ],
          ),
        ]),
      ]),
    ]),
  ])
}
