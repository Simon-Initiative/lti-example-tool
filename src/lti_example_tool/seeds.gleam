import glaml
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lti/data_provider
import lti/deployment.{Deployment}
import lti/registration.{Registration}
import lti_example_tool/utils/logger

pub fn load(lti_data_provider) -> Result(Nil, String) {
  use contents <- result.try(
    glaml.parse_file("seeds.yml")
    |> result.replace_error("Failed to load seeds.yml"),
  )

  use doc <- result.try(
    list.first(contents) |> result.replace_error("Failed to parse seeds.yml"),
  )

  use platforms <- result.try(
    glaml.select_sugar(glaml.document_root(doc), "platforms")
    |> result.replace_error("Failed to parse platforms from seeds.yml"),
  )

  process_platforms(platforms, lti_data_provider)
}

fn process_platforms(node: glaml.Node, lti_data_provider) -> Result(Nil, String) {
  case node {
    glaml.NodeSeq(seq) -> {
      case
        result.all(
          list.map(seq, fn(node) { process_platform(node, lti_data_provider) }),
        )
      {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(e)
      }
    }
    _ -> {
      Error(
        "Invalid platforms node, expected a sequence but got: "
        <> string.inspect(node),
      )
    }
  }
}

fn process_platform(node: glaml.Node, lti_data_provider) -> Result(Nil, String) {
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

      use #(registration_id, _registration) <- result.try(
        data_provider.create_registration(
          lti_data_provider,
          Registration(
            name,
            issuer,
            client_id,
            auth_endpoint,
            access_token_endpoint,
            keyset_url,
          ),
        )
        |> result.replace_error("Failed to create registration"),
      )
      use _deployment <- result.try(
        data_provider.create_deployment(
          lti_data_provider,
          Deployment(deployment_id, registration_id),
        )
        |> result.replace_error("Failed to create deployment"),
      )

      logger.info(
        "Created platform with registration ID: "
        <> int.to_string(registration_id),
      )

      Ok(Nil)
    }
    _ -> {
      Error(
        "Invalid platform node, expected a map but got: "
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
