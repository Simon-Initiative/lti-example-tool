import gleam/dynamic/decode
import lti/registration.{type Registration, Registration}
import lti_example_tool/database.{type Database, Record, one, rows}
import pog

fn platform_decoder() {
  use id <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  use issuer <- decode.field(2, decode.string)
  use client_id <- decode.field(3, decode.string)
  use auth_endpoint <- decode.field(4, decode.string)
  use access_token_endpoint <- decode.field(5, decode.string)
  use keyset_url <- decode.field(6, decode.string)

  use created_at <- decode.field(7, pog.timestamp_decoder())
  use updated_at <- decode.field(8, pog.timestamp_decoder())

  decode.success(Record(
    id,
    created_at,
    updated_at,
    Registration(
      name,
      issuer,
      client_id,
      auth_endpoint,
      access_token_endpoint,
      keyset_url,
    ),
  ))
}

pub fn all(db: Database) {
  "SELECT * FROM platforms"
  |> pog.query()
  |> pog.returning(platform_decoder())
  |> pog.execute(db)
  |> rows()
}

pub fn get(db: Database, id: Int) {
  "SELECT * FROM platforms WHERE id = $1"
  |> pog.query()
  |> pog.parameter(pog.int(id))
  |> pog.returning(platform_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn get_by_issuer_client_id(db: Database, issuer: String, client_id: String) {
  "SELECT * FROM platforms WHERE issuer = $1 AND client_id = $2"
  |> pog.query()
  |> pog.parameter(pog.text(issuer))
  |> pog.parameter(pog.text(client_id))
  |> pog.returning(platform_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn insert(db: Database, platform: Registration) {
  "INSERT INTO platforms (name, issuer, client_id, auth_endpoint, access_token_endpoint, keyset_url) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id"
  |> pog.query()
  |> pog.parameter(pog.text(platform.name))
  |> pog.parameter(pog.text(platform.issuer))
  |> pog.parameter(pog.text(platform.client_id))
  |> pog.parameter(pog.text(platform.auth_endpoint))
  |> pog.parameter(pog.text(platform.access_token_endpoint))
  |> pog.parameter(pog.text(platform.keyset_url))
  |> pog.returning(decode.at([0], decode.int))
  |> pog.execute(db)
  |> one()
}

pub fn update(db: Database, record: #(Int, Registration)) {
  let #(id, platform) = record

  "UPDATE platforms SET name = $1, issuer = $2, client_id = $3, auth_endpoint = $4, access_token_endpoint = $5, keyset_url = $6 WHERE id = $7"
  |> pog.query()
  |> pog.parameter(pog.text(platform.name))
  |> pog.parameter(pog.text(platform.issuer))
  |> pog.parameter(pog.text(platform.client_id))
  |> pog.parameter(pog.text(platform.auth_endpoint))
  |> pog.parameter(pog.text(platform.access_token_endpoint))
  |> pog.parameter(pog.text(platform.keyset_url))
  |> pog.parameter(pog.int(id))
  |> pog.execute(db)
  |> one()
}

pub fn delete(db: Database, id: Int) {
  "DELETE FROM platforms WHERE id = $1"
  |> pog.query()
  |> pog.parameter(pog.int(id))
  |> pog.execute(db)
  |> one()
}
// pub fn platform_to_registration(platform: Platform) -> Registration {
//   Registration(
//     platform.name,
//     platform.issuer,
//     platform.client_id,
//     platform.auth_endpoint,
//     platform.access_token_endpoint,
//     platform.keyset_url,
//   )
// }

// pub fn registration_to_platform(registration: Registration) -> Platform {
//   Platform(
//     registration.name,
//     registration.issuer,
//     registration.client_id,
//     registration.auth_endpoint,
//     registration.access_token_endpoint,
//     registration.keyset_url,
//   )
// }
