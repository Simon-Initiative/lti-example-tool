import formal/form.{type Form}
import gleam/int
import gleam/string
import lightbulb/registration.{type Registration}
import lightbulb/services/access_token.{type AccessToken, AccessToken}
import lightbulb/services/ags
import lightbulb/services/nrps
import lti_example_tool/database.{type Record, Record}
import lti_example_tool/html/components.{DangerLink, Link, Primary, Secondary}
import lti_example_tool/html/components/forms.{Text}
import lti_example_tool/html/components/page.{page}
import lti_example_tool/html/components/tables.{Column}
import nakai/attr.{action, class, href, method, type_}
import nakai/html.{type Node, code, div, h2, p, pre}

pub fn index(registrations: List(Record(Int, Registration))) -> Node {
  page("All Registrations", [
    div([class("flex flex-row justify-end mb-4")], [
      components.link(Primary, [href("/registrations/new")], [
        html.Text("Register Platform"),
      ]),
    ]),
    tables.table(
      [],
      [
        Column("ID", fn(record: Record(Int, Registration)) {
          let Record(id, ..) = record
          html.Text(int.to_string(id))
        }),
        Column("Name", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          html.Text(registration.name)
        }),
        Column("Issuer", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          html.Text(registration.issuer)
        }),
        Column("Client ID", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          html.Text(registration.client_id)
        }),
        Column("Actions", fn(record: Record(Int, Registration)) {
          let Record(id, ..) = record
          div([], [
            components.link(
              Link,
              [href("/registrations/" <> int.to_string(id))],
              [html.Text("View")],
            ),
          ])
        }),
      ],
      registrations,
    ),
  ])
}

pub fn show(registration_id: String, registration: Registration) -> Node {
  page("Platform Registration Details", [
    components.link(Link, [href("/registrations")], [
      html.Text("Back to Registrations"),
    ]),
    div([class("flex flex-col p-6")], [
      div([class("text-2xl font-bold")], [html.Text(registration.name)]),
      div([class("text-gray-500")], [html.Text(registration.issuer)]),
      div([class("text-gray-500")], [html.Text(registration.client_id)]),
      div([class("text-gray-500")], [html.Text(registration.auth_endpoint)]),
      div([class("text-gray-500")], [
        html.Text(registration.access_token_endpoint),
      ]),
      div([class("text-gray-500")], [html.Text(registration.keyset_url)]),
      div([], [
        html.form(
          [
            method("post"),
            action("/registrations/" <> registration_id <> "/access_token"),
          ],
          [
            div([class("flex flex-row")], [
              components.button(Secondary, [class("my-8"), type_("submit")], [
                html.Text("Request Access Token"),
              ]),
            ]),
          ],
        ),
      ]),
    ]),
    div([class("flex flex-row")], [
      components.link(
        Link,
        [href("/registrations/" <> registration_id <> "/edit")],
        [html.Text("Edit")],
      ),
      html.form(
        [
          method("post"),
          action("/registrations/" <> registration_id <> "/delete"),
        ],
        [
          div([class("flex flex-row")], [
            components.button(DangerLink, [class("ml-2"), type_("submit")], [
              html.Text("Delete"),
            ]),
          ]),
        ],
      ),
    ]),
  ])
}

pub fn edit(
  title: String,
  f: Form,
  submit_action: #(String, String),
  cancel_action: #(String, String),
) {
  page(title, [
    components.card([class("max-w-sm mx-auto")], [
      html.form([method("post"), action(submit_action.1)], [
        div([class("flex flex-col")], [
          forms.labeled_input(Text, "Name", "name", form.value(f, "name")),
          forms.labeled_input(Text, "Issuer", "issuer", form.value(f, "issuer")),
          forms.labeled_input(
            Text,
            "Client ID",
            "client_id",
            form.value(f, "client_id"),
          ),
          forms.labeled_input(
            Text,
            "Auth Endpoint",
            "auth_endpoint",
            form.value(f, "auth_endpoint"),
          ),
          forms.labeled_input(
            Text,
            "Access Token Endpoint",
            "access_token_endpoint",
            form.value(f, "access_token_endpoint"),
          ),
          forms.labeled_input(
            Text,
            "Keyset URL",
            "keyset_url",
            form.value(f, "keyset_url"),
          ),
          forms.labeled_input(
            Text,
            "Deployment ID",
            "deployment_id",
            form.value(f, "deployment_id"),
          ),
          components.button(Primary, [class("my-8"), type_("submit")], [
            html.Text(submit_action.0),
          ]),
          components.link(
            Secondary,
            [class("my-2 text-center"), href(cancel_action.1)],
            [html.Text(cancel_action.0)],
          ),
        ]),
      ]),
    ]),
  ])
}

pub fn access_token(
  registration_id: String,
  access_token: AccessToken,
  registration: Registration,
) {
  let AccessToken(
    token: token,
    token_type: token_type,
    expires_in: expires_in,
    ..,
  ) = access_token

  page("Access Token", [
    div([class("flex flex-col items-center justify-center w-full")], [
      div([class("w-full max-w-4xl p-4")], [
        h2([class("my-4 text-lg font-bold")], [html.Text("Issuer")]),
        p([class("")], [html.Text(registration.issuer)]),
        h2([class("my-4 text-lg font-bold")], [html.Text("Token")]),
        pre([class("p-6 bg-gray-100 rounded-lg break-words overflow-auto")], [
          code([class("text-sm break-words")], [html.Text(token)]),
        ]),
        h2([class("my-4 text-lg font-bold mt-4")], [html.Text("Scopes")]),
        pre([class("p-6 bg-gray-100 rounded-lg break-words overflow-auto")], [
          code([class("text-sm break-words")], [
            html.Text(string.join(
              [
                ags.lineitem_scope_url,
                ags.result_readonly_scope_url,
                ags.scores_scope_url,
                nrps.context_membership_readonly_claim_url,
              ],
              "\n",
            )),
          ]),
        ]),
        h2([class("my-4 text-lg font-bold")], [html.Text("Token Type")]),
        pre([class("p-6 bg-gray-100 rounded-lg break-words overflow-auto")], [
          code([class("text-sm break-words")], [html.Text(token_type)]),
        ]),
        h2([class("my-4 text-lg font-bold")], [html.Text("Expires In")]),
        pre([class("p-6 bg-gray-100 rounded-lg break-words overflow-auto")], [
          code([class("text-sm break-words")], [
            html.Text(int.to_string(expires_in)),
          ]),
        ]),
      ]),
      div([class("flex flex-row space-x-4")], [
        components.link(Link, [href("/registrations/" <> registration_id)], [
          html.Text("Back to Registration"),
        ]),
      ]),
    ]),
  ])
}
