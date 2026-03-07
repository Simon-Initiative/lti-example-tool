import gleam/list

pub type ExampleResource {
  Resource1
  Resource2
  Resource3
}

pub fn all() -> List(ExampleResource) {
  [Resource1, Resource2, Resource3]
}

pub fn parse(resource_id: String) -> Result(ExampleResource, String) {
  case resource_id {
    "resource-1" -> Ok(Resource1)
    "resource-2" -> Ok(Resource2)
    "resource-3" -> Ok(Resource3)
    _ -> Error("Invalid resource id")
  }
}

pub fn id(resource: ExampleResource) -> String {
  case resource {
    Resource1 -> "resource-1"
    Resource2 -> "resource-2"
    Resource3 -> "resource-3"
  }
}

pub fn title(resource: ExampleResource) -> String {
  case resource {
    Resource1 -> "Resource 1"
    Resource2 -> "Resource 2"
    Resource3 -> "Resource 3"
  }
}

pub fn from_custom_resource_id(resource_id: String) -> String {
  case parse(resource_id) {
    Ok(resource) -> title(resource)
    Error(_) -> resource_id
  }
}

pub fn ids() -> List(String) {
  all() |> list.map(id)
}
