import lti_example_tool/html/components/page.{page}
import nakai/attr.{Attr, class, href, id, role, tabindex, title}
import nakai/html.{type Node, Text, a, a_text, code, div, h3, li, ol, p, span}

pub fn index(url: String) -> Node {
  page("LTI Example Tool", [
    div([class("container mx-auto")], [
      h3([class("text-xl font-semibold mt-6 mb-2")], [Text("Getting Started")]),
      ol([class("list-decimal ml-6 mb-4")], [
        li([], [
          Text(
            "Register this tool with your LMS or Platform using the following parameters:",
          ),
        ]),
        div([class("ml-6 mb-4 space-y-1")], [
          div([], [
            span([class("font-bold")], [Text("Target Link URI: ")]),
            copyable_code("target-link", url <> "/launch"),
          ]),
          div([], [
            span([class("font-bold")], [Text("Client ID: ")]),
            copyable_code("client-id", "EXAMPLE_CLIENT_ID"),
          ]),
          div([], [
            span([class("font-bold")], [Text("Login URL: ")]),
            copyable_code("login-url", url <> "/login"),
          ]),
          div([], [
            span([class("font-bold")], [Text("Keyset URL: ")]),
            copyable_code("keyset-url", url <> "/.well-known/jwks.json"),
          ]),
          div([], [
            span([class("font-bold")], [Text("Redirect URIs: ")]),
            copyable_code("redirect-uris", url <> "/launch"),
          ]),
        ]),
        li([], [
          a([href("/registrations"), class("text-blue-600 hover:underline")], [
            Text("Create a new Registration"),
          ]),
          Text(
            " in this tool with details provided by your LMS/Platform. For example:",
          ),
        ]),
        div([class("ml-6 mb-4 space-y-1")], [
          div([], [
            span([class("font-bold")], [Text("Name: ")]),
            code([class("bg-gray-100 px-2 py-1 rounded")], [
              Text("Platform Name"),
            ]),
          ]),
          div([], [
            span([class("font-bold")], [Text("Issuer: ")]),
            code([class("bg-gray-100 px-2 py-1 rounded")], [
              Text("https://platform.example.edu"),
            ]),
          ]),
          div([], [
            span([class("font-bold")], [Text("Client ID: ")]),
            code([class("bg-gray-100 px-2 py-1 rounded")], [
              Text("EXAMPLE_CLIENT_ID"),
            ]),
          ]),
          div([], [
            span([class("font-bold")], [Text("Auth Endpoint: ")]),
            code([class("bg-gray-100 px-2 py-1 rounded")], [
              Text("https://platform.example.edu/lti/authorize"),
            ]),
          ]),
          div([], [
            span([class("font-bold")], [Text("Access Token Endpoint: ")]),
            code([class("bg-gray-100 px-2 py-1 rounded")], [
              Text("https://platform.example.edu/auth/token"),
            ]),
          ]),
          div([], [
            span([class("font-bold")], [Text("Keyset URL: ")]),
            code([class("bg-gray-100 px-2 py-1 rounded")], [
              Text("https://platform.example.edu/.well-known/jwks.json"),
            ]),
          ]),
          div([], [
            span([class("font-bold")], [Text("Deployment ID: ")]),
            code([class("bg-gray-100 px-2 py-1 rounded")], [
              Text("some-deployment-id"),
            ]),
          ]),
        ]),
        li([], [
          Text(
            "If running in Docker, use a public URL (not localhost) for registration and set the PUBLIC_URL env. Tools like ",
          ),
          a(
            [href("https://ngrok.com/"), class("text-blue-600 hover:underline")],
            [Text("ngrok")],
          ),
          Text(" can help expose your local server."),
        ]),
      ]),
      h3([class("text-xl font-semibold mt-6 mb-2")], [Text("Development")]),
      p([], [
        Text("See the "),
        a_text(
          [
            href("https://github.com/Simon-Initiative/lti-example-tool"),
            class("text-blue-600 hover:underline"),
          ],
          "README",
        ),
        Text(
          " for instructions on running the tool locally, installing dependencies, and resetting the database.",
        ),
      ]),
    ]),
  ])
}

fn copyable_code(id_: String, value: String) -> Node {
  div([class("inline-flex items-center group")], [
    code([id(id_), class("bg-gray-100 px-2 py-1 rounded")], [Text(value)]),
    span(
      [
        Attr(
          "onclick",
          "navigator.clipboard.writeText(document.getElementById('"
            <> id_
            <> "').innerText)",
        ),
        class(
          "ml-2 text-xs font-semibold text-blue-600 bg-blue-100 px-2 py-1 rounded cursor-pointer hover:bg-blue-200 transition",
        ),
        title("Copy to clipboard"),
        tabindex("0"),
        role("button"),
      ],
      [Text("COPY")],
    ),
  ])
}
