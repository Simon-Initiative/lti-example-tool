import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import lightbulb/deep_linking/settings.{
  type DeepLinkingSettings, DeepLinkingSettings,
}
import lti_example_tool/database.{type Database, one}
import lti_example_tool/utils/logger
import pog
import youid/uuid

pub type DeepLinkingContext {
  DeepLinkingContext(
    context_token: String,
    iss: String,
    aud: String,
    deployment_id: String,
    deep_link_return_url: String,
    request_data: Option(String),
    accept_types: List(String),
    accept_multiple: Option(Bool),
    accept_lineitem: Option(Bool),
    created_at: timestamp.Timestamp,
    expires_at: timestamp.Timestamp,
    consumed_at: Option(timestamp.Timestamp),
  )
}

pub type NewDeepLinkingContext {
  NewDeepLinkingContext(
    iss: String,
    aud: String,
    deployment_id: String,
    deep_link_return_url: String,
    request_data: Option(String),
    accept_types: List(String),
    accept_multiple: Option(Bool),
    accept_lineitem: Option(Bool),
    ttl_seconds: Int,
  )
}

pub type ConsumeError {
  ContextMissing
  ContextExpired
  ContextConsumed
  ContextStorageError(reason: String)
}

pub fn consume_error_to_string(error: ConsumeError) -> String {
  case error {
    ContextMissing -> "Deep-linking request context was not found."
    ContextExpired -> "Deep-linking request context expired."
    ContextConsumed -> "Deep-linking request context was already used."
    ContextStorageError(reason) -> reason
  }
}

fn context_decoder() -> decode.Decoder(DeepLinkingContext) {
  use context_token <- decode.field(0, decode.string)
  use iss <- decode.field(1, decode.string)
  use aud <- decode.field(2, decode.string)
  use deployment_id <- decode.field(3, decode.string)
  use deep_link_return_url <- decode.field(4, decode.string)
  use request_data <- decode.field(5, decode.optional(decode.string))
  use accept_types_raw <- decode.field(6, decode.string)
  use accept_multiple <- decode.field(7, decode.optional(decode.bool))
  use accept_lineitem <- decode.field(8, decode.optional(decode.bool))
  use created_at <- decode.field(9, pog.timestamp_decoder())
  use expires_at <- decode.field(10, pog.timestamp_decoder())
  use consumed_at <- decode.field(11, decode.optional(pog.timestamp_decoder()))

  decode.success(DeepLinkingContext(
    context_token: context_token,
    iss: iss,
    aud: aud,
    deployment_id: deployment_id,
    deep_link_return_url: deep_link_return_url,
    request_data: request_data,
    accept_types: decode_accept_types(accept_types_raw),
    accept_multiple: accept_multiple,
    accept_lineitem: accept_lineitem,
    created_at: created_at,
    expires_at: expires_at,
    consumed_at: consumed_at,
  ))
}

pub fn create_context(
  db: Database,
  context: NewDeepLinkingContext,
) -> Result(String, String) {
  let token = uuid.v4_string()
  let now = timestamp.system_time()
  let expires_at = now |> timestamp.add(duration.seconds(context.ttl_seconds))

  "INSERT INTO deep_linking_contexts
   (context_token, iss, aud, deployment_id, deep_link_return_url, request_data, accept_types, accept_multiple, accept_lineitem, created_at, expires_at)
   VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)"
  |> pog.query()
  |> pog.parameter(pog.text(token))
  |> pog.parameter(pog.text(context.iss))
  |> pog.parameter(pog.text(context.aud))
  |> pog.parameter(pog.text(context.deployment_id))
  |> pog.parameter(pog.text(context.deep_link_return_url))
  |> pog.parameter(case context.request_data {
    Some(text) -> pog.text(text)
    None -> pog.null()
  })
  |> pog.parameter(pog.text(encode_accept_types(context.accept_types)))
  |> pog.parameter(case context.accept_multiple {
    Some(bool) -> pog.bool(bool)
    None -> pog.null()
  })
  |> pog.parameter(case context.accept_lineitem {
    Some(bool) -> pog.bool(bool)
    None -> pog.null()
  })
  |> pog.parameter(pog.timestamp(now))
  |> pog.parameter(pog.timestamp(expires_at))
  |> pog.execute(db)
  |> result.map(fn(_) { token })
  |> result.map_error(fn(e) {
    logger.error_meta("Failed to store deep-linking context", e)

    "Failed to store deep-linking context"
  })
}

pub fn consume_context(
  db: Database,
  context_token: String,
) -> Result(DeepLinkingContext, ConsumeError) {
  let now = timestamp.system_time()

  let consume_result =
    "UPDATE deep_linking_contexts
     SET consumed_at = $2
     WHERE context_token = $1
       AND consumed_at IS NULL
       AND expires_at > $2
     RETURNING context_token, iss, aud, deployment_id, deep_link_return_url, request_data, accept_types, accept_multiple, accept_lineitem, created_at, expires_at, consumed_at"
    |> pog.query()
    |> pog.parameter(pog.text(context_token))
    |> pog.parameter(pog.timestamp(now))
    |> pog.returning(context_decoder())
    |> pog.execute(db)
    |> one()

  case consume_result {
    Ok(context) -> Ok(context)
    Error(_) ->
      find_context_by_token(db, context_token)
      |> result.map_error(fn(error) {
        logger.error_meta("Failed to read deep-linking context state", error)

        ContextStorageError("Failed to read deep-linking context")
      })
      |> result.try(classify_rejected_context)
  }
}

pub fn to_settings(context: DeepLinkingContext) -> DeepLinkingSettings {
  DeepLinkingSettings(
    deep_link_return_url: context.deep_link_return_url,
    accept_types: context.accept_types,
    accept_presentation_document_targets: [],
    accept_media_types: None,
    accept_multiple: context.accept_multiple,
    auto_create: None,
    title: None,
    text: None,
    data: context.request_data,
    accept_lineitem: context.accept_lineitem,
  )
}

fn classify_rejected_context(
  context: Option(DeepLinkingContext),
) -> Result(DeepLinkingContext, ConsumeError) {
  case context {
    None -> Error(ContextMissing)
    Some(context) ->
      case context.consumed_at {
        Some(_) -> Error(ContextConsumed)
        None ->
          case timestamp.compare(context.expires_at, timestamp.system_time()) {
            order.Gt -> Error(ContextConsumed)
            _ -> Error(ContextExpired)
          }
      }
  }
}

fn find_context_by_token(db: Database, context_token: String) {
  "SELECT context_token, iss, aud, deployment_id, deep_link_return_url, request_data, accept_types, accept_multiple, accept_lineitem, created_at, expires_at, consumed_at
   FROM deep_linking_contexts
   WHERE context_token = $1"
  |> pog.query()
  |> pog.parameter(pog.text(context_token))
  |> pog.returning(context_decoder())
  |> pog.execute(db)
  |> result.map(fn(returned) {
    case returned.rows {
      [context] -> Some(context)
      _ -> None
    }
  })
}

fn encode_accept_types(accept_types: List(String)) -> String {
  accept_types
  |> list.filter(fn(value) { string.trim(value) != "" })
  |> string.join(",")
}

fn decode_accept_types(raw: String) -> List(String) {
  raw
  |> string.split(",")
  |> list.filter(fn(value) { string.trim(value) != "" })
}
