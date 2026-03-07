import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lightbulb/services/ags.{AgsClaim}
import lightbulb/services/nrps
import lightbulb/services/nrps/membership.{type Membership}
import lti_example_tool/app_context.{type AppContext}
import lti_example_tool/database.{Record}
import lti_example_tool/deep_link_resources
import lti_example_tool/registrations
import lti_example_tool_web/html/components.{Primary}
import lti_example_tool_web/html/components/forms.{Number, Text}
import lti_example_tool_web/html/components/page.{app_page, page}
import lti_example_tool_web/html/components/tables.{Column}
import nakai/attr.{action, class, href, id, method, name, src, type_, value}
import nakai/html.{type Node, div, form, h2, i, img, input, p, section, span}

pub fn client_app(_app: AppContext) -> Node {
  app_page([
    div([class("mx-auto max-w-3xl w-full px-4 py-6")], [
      div([id("root")], []),
      html.Script(
        [
          type_("module"),
          src("/static/client/client-app.js"),
        ],
        "",
      ),
    ]),
  ])
}

pub fn launch_details(
  claims: Dict(String, Dynamic),
  app: AppContext,
  bootstrap_token: String,
  selected_resource_title: Option(String),
) -> Node {
  page("Launch Successful", [
    div([class("container mx-auto flex flex-col gap-12")], [
      selected_resource_section(selected_resource_title),
      claims_section(claims),
      ags_section(app, claims),
      nrps_section(app, claims),
      section([], [
        heading("Client App"),
        components.link(Primary, [href("/app"), class("inline-block my-2")], [
          html.Text("Open Client App"),
        ]),
        html.Script(
          [],
          "sessionStorage.setItem('lti_bootstrap_token', '"
            <> bootstrap_token
            <> "');",
        ),
      ]),
    ]),
  ])
}

pub fn deep_linking_resource_picker(context_token: String) -> Node {
  page("Choose A Resource", [
    div([class("container mx-auto flex flex-col gap-6")], [
      section([], [
        heading("Deep Linking Resource Picker"),
        p([class("text-gray-600")], [
          html.Text(
            "Select one example resource and return it to the platform.",
          ),
        ]),
      ]),
      div([class("grid gap-4 md:grid-cols-3")], [
        deep_linking_choice_card(
          context_token,
          deep_link_resources.Resource1,
          "Intro example content",
        ),
        deep_linking_choice_card(
          context_token,
          deep_link_resources.Resource2,
          "Practice example content",
        ),
        deep_linking_choice_card(
          context_token,
          deep_link_resources.Resource3,
          "Assessment example content",
        ),
      ]),
    ]),
  ])
}

fn heading(content: String) -> Node {
  h2([class("text-xl font-bold mb-2")], [html.Text(content)])
}

fn selected_resource_section(selected_resource_title: Option(String)) -> Node {
  case selected_resource_title {
    Some(resource_title) ->
      section([], [
        heading("Deep-Linked Resource"),
        div([class("rounded border border-blue-200 bg-blue-50 p-4")], [
          html.Text("Selected resource: " <> resource_title),
        ]),
      ])
    None -> div([], [])
  }
}

fn deep_linking_choice_card(
  context_token: String,
  resource: deep_link_resources.ExampleResource,
  description: String,
) -> Node {
  div([class("rounded border border-gray-200 bg-white p-4 shadow-sm")], [
    h2([class("text-lg font-semibold mb-2")], [
      html.Text(deep_link_resources.title(resource)),
    ]),
    p([class("text-sm text-gray-600 mb-4")], [html.Text(description)]),
    form([method("post"), action("/deep-linking/respond")], [
      input([type_("hidden"), name("context_token"), value(context_token)]),
      input([
        type_("hidden"),
        name("resource_id"),
        value(deep_link_resources.id(resource)),
      ]),
      components.button(Primary, [type_("submit"), class("w-full")], [
        html.Text("Select " <> deep_link_resources.title(resource)),
      ]),
    ]),
  ])
}

fn claims_section(claims: Dict(String, Dynamic)) -> Node {
  section([], [
    heading("ID Token"),
    div([], [
      div([class("my-2")], [
        i([class("fa-solid fa-lock text-green-500 mr-2")], []),
        html.Text("Token signature verified"),
      ]),
      tables.table(
        [],
        [
          Column("Claim", fn(record: #(String, Dynamic)) {
            let #(claim, _value) = record
            span([class("font-semibold")], [html.Text(claim)])
          }),
          Column("Value", fn(record: #(String, Dynamic)) {
            let #(_key, value) = record

            html.pre_text(
              [class("whitespace-pre-wrap break-all font-mono text-xs")],
              claim_value_json(value),
            )
          }),
        ],
        dict.to_list(claims),
      ),
    ]),
  ])
}

fn claim_value_json(value: Dynamic) -> String {
  value
  |> dynamic_to_json()
  |> json.to_string()
}

fn dynamic_to_json(value: Dynamic) -> json.Json {
  case decode.run(value, decode.string) {
    Ok(v) -> json.string(v)
    Error(_) ->
      case decode.run(value, decode.bool) {
        Ok(v) -> json.bool(v)
        Error(_) ->
          case decode.run(value, decode.int) {
            Ok(v) -> json.int(v)
            Error(_) ->
              case decode.run(value, decode.float) {
                Ok(v) -> json.float(v)
                Error(_) ->
                  case decode.run(value, decode.list(decode.dynamic)) {
                    Ok(values) -> json.array(values, dynamic_to_json)
                    Error(_) ->
                      case
                        decode.run(
                          value,
                          decode.dict(decode.dynamic, decode.dynamic),
                        )
                      {
                        Ok(values) ->
                          json.object(
                            list.map(dict.to_list(values), fn(entry) {
                              let #(k, v) = entry
                              #(dynamic_key_to_string(k), dynamic_to_json(v))
                            }),
                          )
                        Error(_) ->
                          case
                            decode.run(value, decode.optional(decode.dynamic))
                          {
                            Ok(Some(v)) -> dynamic_to_json(v)
                            Ok(_) -> json.null()
                            Error(_) -> json.string(string.inspect(value))
                          }
                      }
                  }
              }
          }
      }
  }
}

fn dynamic_key_to_string(key: Dynamic) -> String {
  case decode.run(key, decode.string) {
    Ok(value) -> value
    Error(_) -> string.inspect(key)
  }
}

fn decode_string(d: Dynamic) -> Result(String, String) {
  decode.run(d, decode.string)
  |> result.replace_error("Invalid string: " <> string.inspect(d))
}

fn ags_section(app: AppContext, claims: Dict(String, Dynamic)) -> Node {
  let form = {
    use user_id <- result.try(
      dict.get(claims, "sub")
      |> result.replace_error("Missing user_id")
      |> result.try(decode_string),
    )

    use resource_id <- result.try(
      dict.get(
        claims,
        "https://purl.imsglobal.org/spec/lti/claim/resource_link",
      )
      |> result.replace_error("Missing resource_link")
      |> result.try(fn(d) {
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
      |> result.try(decode_string),
    )

    use client_id <- result.try(
      dict.get(claims, "aud")
      |> result.replace_error("Missing aud")
      |> result.try(decode_string),
    )

    use ags_claim <- result.try(ags.get_lti_ags_claim(claims))

    use Record(id: registration_id, ..) <- result.try(
      registrations.get_by_issuer_client_id(app.db, issuer, client_id)
      |> result.replace_error("Error fetching registration"),
    )

    case ags_claim {
      AgsClaim(lineitems: Some(line_items_service_url), ..) ->
        Ok(form_for_lineitems(
          line_items_service_url,
          registration_id,
          user_id,
          resource_id,
        ))
      AgsClaim(lineitem: Some(line_item_service_url), ..) ->
        Ok(form_for_lineitem(
          line_item_service_url,
          registration_id,
          user_id,
          resource_id,
        ))
      _ ->
        Error(
          "AGS Service is not available. No line items or line item service URL found in claims.",
        )
    }
  }

  section([], [
    heading("Assignment and Grade Services"),
    case form {
      Ok(form) ->
        div([], [
          div([class("my-2")], [
            i([class("fa-solid fa-circle-check text-green-500 mr-2")], []),
            html.Text("AGS Service is available"),
          ]),
          form,
        ])
      Error(reason) ->
        div([], [
          div([class("my-2")], [
            i([class("fa-solid fa-circle-xmark text-gray-500 mr-2")], []),
            html.Text("AGS Service is not available"),
          ]),
          div([class("text-red-500")], [html.Text(reason)]),
        ])
    },
  ])
}

fn form_for_lineitem(
  line_item_service_url: String,
  registration_id: Int,
  user_id: String,
  resource_id: String,
) -> Node {
  form([method("post"), action("/score")], [
    div([class("my-2 text-gray-500")], [
      span([class("my-2 font-mono")], [html.Text(line_item_service_url)]),
    ]),
    div([class("my-2 text-gray-500")], [
      span([class("my-2 font-mono")], [
        html.Text("Resource ID: " <> resource_id),
      ]),
    ]),
    forms.labeled_input(Number, "Score Given", "score_given", ""),
    forms.labeled_input(Number, "Score Maximum", "score_maximum", ""),
    forms.labeled_input(Text, "Comment", "comment", ""),
    input([type_("hidden"), name("user_id"), value(user_id)]),
    input([type_("hidden"), name("resource_id"), value(resource_id)]),
    input([
      type_("hidden"),
      name("registration_id"),
      value(int.to_string(registration_id)),
    ]),
    input([
      type_("hidden"),
      name("line_item_service_url"),
      value(line_item_service_url),
    ]),
    components.button(Primary, [class("my-8"), type_("submit")], [
      html.Text("Send Score"),
    ]),
  ])
}

fn form_for_lineitems(
  line_items_service_url: String,
  registration_id: Int,
  user_id: String,
  resource_id: String,
) -> Node {
  form([method("post"), action("/score")], [
    div([class("my-2 text-gray-500")], [
      span([class("my-2 font-mono")], [html.Text(line_items_service_url)]),
    ]),
    forms.labeled_input(Text, "Resource ID", "resource_id", resource_id),
    forms.labeled_input(
      Text,
      "Line Item Name",
      "line_item_name",
      "Example Assignment",
    ),
    forms.labeled_input(Number, "Score Given", "score_given", ""),
    forms.labeled_input(Number, "Score Maximum", "score_maximum", ""),
    forms.labeled_input(Text, "Comment", "comment", ""),
    input([type_("hidden"), name("user_id"), value(user_id)]),
    input([
      type_("hidden"),
      name("registration_id"),
      value(int.to_string(registration_id)),
    ]),
    input([
      type_("hidden"),
      name("line_items_service_url"),
      value(line_items_service_url),
    ]),
    components.button(Primary, [class("my-8"), type_("submit")], [
      html.Text("Send Score"),
    ]),
  ])
}

pub fn nrps_section(app: AppContext, claims: Dict(String, Dynamic)) -> Node {
  let form = {
    use context_memberships_url <- result.try(
      nrps.get_membership_service_url(claims)
      |> result.map_error(nrps.nrps_error_to_string),
    )

    use issuer <- result.try(
      dict.get(claims, "iss")
      |> result.replace_error("Missing iss")
      |> result.try(decode_string),
    )

    use client_id <- result.try(
      dict.get(claims, "aud")
      |> result.replace_error("Missing aud")
      |> result.try(decode_string),
    )

    use registration <- result.try(
      registrations.get_by_issuer_client_id(app.db, issuer, client_id)
      |> result.replace_error("Error fetching registration"),
    )

    form([method("post"), action("/memberships")], [
      div([class("my-2 text-gray-500")], [
        span([class("my-2 font-mono")], [html.Text(context_memberships_url)]),
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
        html.Text("Fetch Memberships"),
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
            html.Text("NRPS Service is available"),
          ]),
          form,
        ])
      Error(reason) ->
        div([], [
          div([class("my-2")], [
            i([class("fa-solid fa-circle-xmark text-gray-500 mr-2")], []),
            html.Text("NRPS Service is not available"),
          ]),
          div([class("text-red-500")], [html.Text(reason)]),
        ])
    },
  ])
}

pub fn score_sent() -> Node {
  page("Success", [
    div([class("container mx-auto")], [
      div([class("text-green-500 text-center")], [
        html.Text("Score update was successfully sent!"),
      ]),
    ]),
  ])
}

pub fn memberships(memberships: List(Membership)) -> Node {
  page("Memberships", [
    div([class("container mx-auto")], [
      div([class("overflow-x-auto")], [
        tables.table(
          [],
          [
            Column("", fn(m: Membership) {
              case m.picture {
                Some(url) ->
                  img([
                    src(url),
                    class(
                      "w-10 min-w-10 h-10 rounded-full object-cover border-2 border-gray-100",
                    ),
                  ])
                None ->
                  div(
                    [
                      class(
                        "w-10 min-w-10 h-10 rounded-full border-2 border-gray-100 bg-gray-100",
                      ),
                    ],
                    [],
                  )
              }
            }),
            Column("Name", fn(m: Membership) {
              html.Text(option_string(m.name))
            }),
            Column("User ID", fn(m: Membership) {
              span([class("font-mono")], [html.Text(m.user_id)])
            }),
            Column("Status", fn(m: Membership) {
              html.Text(option_string(m.status))
            }),
            Column("Roles", fn(m: Membership) {
              html.Text(string.inspect(m.roles))
            }),
            Column("Email", fn(m: Membership) {
              html.Text(option_string(m.email))
            }),
          ],
          memberships,
        ),
      ]),
    ]),
  ])
}

fn option_string(value: Option(String)) -> String {
  case value {
    Some(v) -> v
    None -> "-"
  }
}
