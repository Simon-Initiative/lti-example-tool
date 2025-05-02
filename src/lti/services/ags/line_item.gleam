import gleam/json.{type Json}

pub type LineItem {
  LineItem(id: String, score_maximum: Float, label: String, resource_id: String)
}

pub fn to_json(line_item: LineItem) -> Json {
  let LineItem(id, score_maximum, label, resource_id) = line_item

  json.object([
    #("id", json.string(id)),
    #("scoreMaximum", json.float(score_maximum)),
    #("label", json.string(label)),
    #("resourceId", json.string(resource_id)),
  ])
}
