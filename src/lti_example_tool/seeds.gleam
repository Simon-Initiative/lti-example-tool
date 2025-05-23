import glaml
import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string
import lightbulb/deployment.{Deployment}
import lightbulb/registration.{type Registration, Registration}
import lti_example_tool/database.{type Database}
import lti_example_tool/deployments
import lti_example_tool/registrations
import lti_example_tool/utils/logger

pub fn load_from_file(db: Database, filepath: String) -> Result(Nil, String) {
  use contents <- result.try(
    glaml.parse_file(filepath)
    |> result.replace_error("Failed to load seeds.yml"),
  )

  use doc <- result.try(
    list.first(contents) |> result.replace_error("Failed to parse seeds.yml"),
  )

  use registrations <- result.try(
    glaml.select_sugar(glaml.document_root(doc), "registrations")
    |> result.replace_error("Failed to parse registrations from seeds.yml"),
  )

  use operations <- result.try(process_platform_registrations(registrations))

  perform_operations(db, operations)
  |> result.all()
  |> result.map(fn(_) { Nil })
  |> result.map_error(database.humanize_error)
}

fn process_platform_registrations(
  node: glaml.Node,
) -> Result(List(Operation), String) {
  case node {
    glaml.NodeSeq(seq) -> {
      list.fold(seq, [], fn(acc, node) {
        [process_platform_registration(node), ..acc]
      })
      |> result.all()
    }
    _ -> {
      Error(
        "Invalid registrations node, expected a sequence but got: "
        <> string.inspect(node),
      )
    }
  }
}

fn process_platform_registration(node: glaml.Node) -> Result(Operation, String) {
  case node {
    glaml.NodeMap(map) -> {
      use values <- result.try(
        node_map_to_dict(map) |> result.replace_error("Failed to parse map"),
      )

      use name <- result.try(
        dict.get(values, "name") |> result.replace_error("Missing name"),
      )
      use issuer <- result.try(
        dict.get(values, "issuer") |> result.replace_error("Missing issuer"),
      )
      use client_id <- result.try(
        dict.get(values, "client_id")
        |> result.replace_error("Missing client_id"),
      )
      use auth_endpoint <- result.try(
        dict.get(values, "auth_endpoint")
        |> result.replace_error("Missing auth_endpoint"),
      )
      use access_token_endpoint <- result.try(
        dict.get(values, "access_token_endpoint")
        |> result.replace_error("Missing access_token_endpoint"),
      )
      use keyset_url <- result.try(
        dict.get(values, "keyset_url")
        |> result.replace_error("Missing keyset_url"),
      )
      use deployment_id <- result.try(
        dict.get(values, "deployment_id")
        |> result.replace_error("Missing deployment_id"),
      )

      Ok(CreateRegistration(
        Registration(
          name,
          issuer,
          client_id,
          auth_endpoint,
          access_token_endpoint,
          keyset_url,
        ),
        deployment_id,
      ))
    }
    _ -> {
      Error(
        "Invalid registration node, expected a map but got: "
        <> string.inspect(node),
      )
    }
  }
}

fn node_map_to_dict(
  node_map: List(#(glaml.Node, glaml.Node)),
) -> Result(Dict(String, String), String) {
  list.map(node_map, fn(entry) {
    let #(key, value) = entry

    use key <- string_node(key)
    use value <- string_node(value)

    Ok(#(key, value))
  })
  |> result.values()
  |> dict.from_list()
  |> Ok
}

fn string_node(
  node: glaml.Node,
  cb: fn(String) -> Result(a, String),
) -> Result(a, String) {
  case node {
    glaml.NodeStr(string) -> cb(string)
    _ -> Error("Expected a NodeStr but got: " <> string.inspect(node))
  }
}

type Operation {
  CreateRegistration(registration: Registration, deployment_id: String)
}

fn perform_operations(db: Database, operations: List(Operation)) {
  list.map(operations, fn(operation) {
    case operation {
      CreateRegistration(registration, deployment_id) -> {
        use registration_id <- result.try(
          database.transaction(db, fn(db) {
            registrations.insert(db, registration)
          }),
        )

        use deployment_id <- result.try(
          database.transaction(db, fn(db) {
            deployments.insert(db, Deployment(deployment_id, registration_id))
          }),
        )

        logger.info(
          "Created platform registration with id: "
          <> string.inspect(registration_id)
          <> " and deployment id: "
          <> string.inspect(deployment_id),
        )

        Ok(Nil)
      }
    }
  })
}
