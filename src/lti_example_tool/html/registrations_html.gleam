import gleam/int
import gleam/option.{None}
import gleam/string
import lti/registration.{type Registration}
import lti/services/access_token.{type AccessToken, AccessToken}
import lti/services/ags
import lti/services/nrps
import lti_example_tool/database.{type Record, Record}
import lti_example_tool/html/components.{DangerLink, Link, Primary, Secondary}
import lti_example_tool/html/components/forms.{Text}
import lti_example_tool/html/components/page.{page}
import lti_example_tool/html/components/tables.{Column}
import lustre/attribute.{action, class, href, method, type_}
import lustre/element.{type Element}
import lustre/element/html.{code, div, form, h2, p, pre, text}

pub fn index(registrations: List(Record(Int, Registration))) -> Element(a) {
  page("All Registrations", [
    div([class("flex flex-row justify-end mb-4")], [
      components.link(Primary, [href("/registrations/new")], [
        text("Register Platform"),
      ]),
    ]),
    tables.table(
      [],
      [
        Column("ID", fn(record: Record(Int, Registration)) {
          let Record(id, ..) = record
          text(int.to_string(id))
        }),
        Column("Name", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          text(registration.name)
        }),
        Column("Issuer", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          text(registration.issuer)
        }),
        Column("Client ID", fn(record: Record(Int, Registration)) {
          let Record(data: registration, ..) = record
          text(registration.client_id)
        }),
        Column("Actions", fn(record: Record(Int, Registration)) {
          let Record(id, ..) = record
          div([], [
            components.link(
              Link,
              [href("/registrations/" <> int.to_string(id))],
              [text("View")],
            ),
          ])
        }),
      ],
      registrations,
    ),
  ])
}

pub fn show(registration_id: String, registration: Registration) -> Element(a) {
  page("Platform Registration Details", [
    div([class("flex flex-col")], [
      div([class("text-2xl font-bold")], [text(registration.name)]),
      div([class("text-gray-500")], [text(registration.issuer)]),
      div([class("text-gray-500")], [text(registration.client_id)]),
      div([class("text-gray-500")], [text(registration.auth_endpoint)]),
      div([class("text-gray-500")], [text(registration.access_token_endpoint)]),
      div([class("text-gray-500")], [text(registration.keyset_url)]),
      div([], [
        form(
          [
            method("post"),
            action("/registrations/" <> registration_id <> "/access_token"),
          ],
          [
            div([class("flex flex-row")], [
              components.button(Secondary, [class("my-8"), type_("submit")], [
                text("Request Access Token"),
              ]),
            ]),
          ],
        ),
      ]),
    ]),
    div([class("flex flex-row")], [
      components.link(Link, [href("/registrations")], [
        text("Back to Registrations"),
      ]),
      form(
        [
          method("post"),
          action("/registrations/" <> registration_id <> "/delete"),
        ],
        [
          div([class("flex flex-row")], [
            components.button(DangerLink, [class("ml-2"), type_("submit")], [
              text("Delete"),
            ]),
          ]),
        ],
      ),
    ]),
  ])
}

pub fn new() {
  page("Register Platform", [
    components.card([class("max-w-sm mx-auto")], [
      form([method("post"), action("/registrations")], [
        div([class("flex flex-col")], [
          forms.labeled_input(Text, "Name", "name", None),
          forms.labeled_input(Text, "Issuer", "issuer", None),
          forms.labeled_input(Text, "Client ID", "client_id", None),
          forms.labeled_input(Text, "Auth Endpoint", "auth_endpoint", None),
          forms.labeled_input(
            Text,
            "Access Token Endpoint",
            "access_token_endpoint",
            None,
          ),
          forms.labeled_input(Text, "Keyset URL", "keyset_url", None),
          forms.labeled_input(Text, "Deployment ID", "deployment_id", None),
          components.button(Primary, [class("my-8"), type_("submit")], [
            text("Register"),
          ]),
          components.link(
            Secondary,
            [class("my-2 text-center"), href("/registrations")],
            [text("Cancel")],
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
        h2([class("my-4 text-lg font-bold")], [text("Issuer")]),
        p([class("")], [text(registration.issuer)]),
        h2([class("my-4 text-lg font-bold")], [text("Token")]),
        pre([class("p-6 bg-gray-100 rounded-lg break-words overflow-auto")], [
          code([class("text-sm break-words")], [text(token)]),
        ]),
        h2([class("my-4 text-lg font-bold mt-4")], [text("Scopes")]),
        pre([class("p-6 bg-gray-100 rounded-lg break-words overflow-auto")], [
          code([class("text-sm break-words")], [
            text(string.join(
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
        h2([class("my-4 text-lg font-bold")], [text("Token Type")]),
        pre([class("p-6 bg-gray-100 rounded-lg break-words overflow-auto")], [
          code([class("text-sm break-words")], [text(token_type)]),
        ]),
        h2([class("my-4 text-lg font-bold")], [text("Expires In")]),
        pre([class("p-6 bg-gray-100 rounded-lg break-words overflow-auto")], [
          code([class("text-sm break-words")], [text(int.to_string(expires_in))]),
        ]),
      ]),
      div([class("flex flex-row space-x-4")], [
        components.link(Link, [href("/registrations/" <> registration_id)], [
          text("Back to Registration"),
        ]),
      ]),
    ]),
  ])
}
