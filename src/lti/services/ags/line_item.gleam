import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option}

pub type LineItem {
  LineItem(
    id: Option(String),
    score_maximum: Float,
    label: String,
    resource_id: String,
  )
}

pub fn to_json(line_item: LineItem) -> Json {
  let LineItem(id, score_maximum, label, resource_id) = line_item

  [
    #("scoreMaximum", json.float(score_maximum)),
    #("label", json.string(label)),
    #("resourceId", json.string(resource_id)),
  ]
  |> maybe_add(id, "id", json.string)
  |> json.object()
}

fn maybe_add(
  list: List(#(String, Json)),
  field: Option(a),
  key: String,
  json_encoder: fn(a) -> Json,
) {
  field
  |> option.map(fn(value) { [#(key, json_encoder(value)), ..list] })
  |> option.unwrap(list)
}

pub fn decoder() {
  use id <- decode.field("id", decode.optional(decode.string))
  use score_maximum <- decode.field("scoreMaximum", decode.float)
  use label <- decode.field("label", decode.string)
  use resource_id <- decode.field("resourceId", decode.string)

  decode.success(LineItem(
    id: id,
    score_maximum: score_maximum,
    label: label,
    resource_id: resource_id,
  ))
}
