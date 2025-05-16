import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lti/services/ags
import lti/services/nrps
import lti/services/nrps/membership.{type Membership}
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/html/components.{Primary}
import lti_example_tool/html/components/forms.{Number, Text}
import lti_example_tool/html/components/page.{page}
import lti_example_tool/html/components/tables.{Column}
import lti_example_tool/registrations
import lustre/attribute.{action, class, method, name, src, type_, value}
import lustre/element.{type Element}
import lustre/element/html.{div, form, h2, i, img, input, section, span, text}

pub fn launch_details(
  claims: Dict(String, Dynamic),
  app: AppContext,
) -> Element(a) {
  page("Launch Successful", [
    div([class("container mx-auto flex flex-col gap-12")], [
      claims_section(claims),
      ags_section(app, claims),
      nrps_section(app, claims),
    ]),
  ])
}

fn heading(content: String) -> Element(a) {
  h2([class("text-xl font-bold mb-2")], [text(content)])
}

fn claims_section(claims: Dict(String, Dynamic)) -> Element(a) {
  section([], [
    heading("ID Token"),
    div([], [
      div([class("my-2")], [
        i([class("fa-solid fa-lock text-green-500 mr-2")], []),
        text("Token signature verified"),
      ]),
      tables.table(
        [],
        [
          Column("Claim", fn(record: #(String, Dynamic)) {
            let #(claim, _value) = record
            span([class("font-semibold")], [text(claim)])
          }),
          Column("Value", fn(record: #(String, Dynamic)) {
            let #(_key, value) = record
            text(string.inspect(value))
          }),
        ],
        dict.to_list(claims),
      ),
    ]),
  ])
}

fn decode_string(d: Dynamic) -> Result(String, String) {
  decode.run(d, decode.string)
  |> result.replace_error("Invalid string: " <> string.inspect(d))
}

fn ags_section(app: AppContext, claims: Dict(String, Dynamic)) -> Element(a) {
  let form = {
    use user_id <- result.try(
      dict.get(claims, "sub")
      |> result.replace_error("Missing user_id")
      |> result.then(decode_string),
    )

    use resource_id <- result.try(
      dict.get(
        claims,
        "https://purl.imsglobal.org/spec/lti/claim/resource_link",
      )
      |> result.replace_error("Missing resource_id")
      |> result.then(fn(d) {
        let resource_link_decoder = {
          use id <- decode.field("id", decode.string)

          decode.success(id)
        }

        decode.run(d, resource_link_decoder)
        |> result.replace_error("Invalid resource_link")
      }),
    )

    use issuer <- result.try(
      dict.get(claims, "iss")
      |> result.replace_error("Missing iss")
      |> result.then(decode_string),
    )

    use client_id <- result.try(
      dict.get(claims, "aud")
      |> result.replace_error("Missing aud")
      |> result.then(decode_string),
    )

    use line_items_service_url <- result.try(ags.get_line_items_service_url(
      claims,
    ))

    use registration <- result.try(
      registrations.get_by_issuer_client_id(app.db, issuer, client_id)
      |> result.replace_error("Error fetching registration"),
    )

    form([method("post"), action("/score")], [
      div([class("my-2 text-gray-500")], [
        span([class("my-2 font-mono")], [text(line_items_service_url)]),
      ]),
      forms.labeled_input(
        Text,
        "Line Item ID",
        "line_item_id",
        Some("example_assignment"),
      ),
      forms.labeled_input(
        Text,
        "Line Item Name",
        "line_item_name",
        Some("Example Assignment"),
      ),
      forms.labeled_input(Number, "Score Given", "score_given", None),
      forms.labeled_input(Number, "Score Maximum", "score_maximum", None),
      forms.labeled_input(Text, "Comment", "comment", None),
      input([type_("hidden"), name("user_id"), value(user_id)]),
      input([type_("hidden"), name("resource_id"), value(resource_id)]),
      input([
        type_("hidden"),
        name("registration_id"),
        value(int.to_string(registration.id)),
      ]),
      input([
        type_("hidden"),
        name("line_items_service_url"),
        value(line_items_service_url),
      ]),
      components.button(Primary, [class("my-8"), type_("submit")], [
        text("Send Score"),
      ]),
    ])
    |> Ok
  }

  section([], [
    heading("Assignment and Grade Services"),
    case form {
      Ok(form) ->
        div([], [
          div([class("my-2")], [
            i([class("fa-solid fa-circle-check text-green-500 mr-2")], []),
            text("AGS Service is available"),
          ]),
          form,
        ])
      Error(reason) ->
        div([], [
          div([class("my-2")], [
            i([class("fa-solid fa-circle-xmark text-gray-500 mr-2")], []),
            text("AGS Service is not available"),
          ]),
          div([class("text-red-500")], [text(reason)]),
        ])
    },
  ])
}

pub fn nrps_section(
  app: AppContext,
  claims: Dict(String, Dynamic),
) -> Element(a) {
  let form = {
    use context_memberships_url <- result.try(nrps.get_membership_service_url(
      claims,
    ))

    use issuer <- result.try(
      dict.get(claims, "iss")
      |> result.replace_error("Missing iss")
      |> result.then(decode_string),
    )

    use client_id <- result.try(
      dict.get(claims, "aud")
      |> result.replace_error("Missing aud")
      |> result.then(decode_string),
    )

    use registration <- result.try(
      registrations.get_by_issuer_client_id(app.db, issuer, client_id)
      |> result.replace_error("Error fetching registration"),
    )

    form([method("post"), action("/memberships")], [
      div([class("my-2 text-gray-500")], [
        span([class("my-2 font-mono")], [text(context_memberships_url)]),
      ]),
      input([
        type_("hidden"),
        name("context_memberships_url"),
        value(context_memberships_url),
      ]),
      input([
        type_("hidden"),
        name("registration_id"),
        value(int.to_string(registration.id)),
      ]),
      components.button(Primary, [class("my-8"), type_("submit")], [
        text("Fetch Memberships"),
      ]),
    ])
    |> Ok
  }

  section([], [
    heading("Names and Roles Provisioning Services"),
    case form {
      Ok(form) ->
        div([], [
          div([class("my-2")], [
            i([class("fa-solid fa-circle-check text-green-500 mr-2")], []),
            text("NRPS Service is available"),
          ]),
          form,
        ])
      Error(reason) ->
        div([], [
          div([class("my-2")], [
            i([class("fa-solid fa-circle-xmark text-gray-500 mr-2")], []),
            text("NRPS Service is not available"),
          ]),
          div([class("text-red-500")], [text(reason)]),
        ])
    },
  ])
}

pub fn score_sent() -> Element(a) {
  page("Success", [
    div([class("container mx-auto")], [
      div([class("text-green-500 text-center")], [
        text("Score update was successfully sent!"),
      ]),
    ]),
  ])
}

pub fn memberships(memberships: List(Membership)) -> Element(a) {
  page("Memberships", [
    div([class("container mx-auto")], [
      div([class("overflow-x-auto")], [
        tables.table(
          [],
          [
            Column("", fn(m: Membership) {
              img([
                src(m.picture),
                class(
                  "w-10 min-w-10 h-10 rounded-full object-cover border-2 border-gray-100",
                ),
              ])
            }),
            Column("Name", fn(m: Membership) { text(m.name) }),
            Column("User ID", fn(m: Membership) {
              span([class("font-mono")], [text(m.user_id)])
            }),
            Column("Status", fn(m: Membership) { text(m.status) }),
            Column("Roles", fn(m: Membership) { text(string.inspect(m.roles)) }),
            Column("Email", fn(m: Membership) { text(m.email) }),
          ],
          memberships,
        ),
      ]),
    ]),
  ])
}
