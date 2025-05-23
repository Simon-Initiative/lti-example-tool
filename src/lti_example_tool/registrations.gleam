import gleam/dynamic/decode
import lightbulb/registration.{type Registration, Registration}
import lti_example_tool/database.{type Database, Record, one, rows}
import pog

fn registration_decoder() {
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
  "SELECT * FROM registrations"
  |> pog.query()
  |> pog.returning(registration_decoder())
  |> pog.execute(db)
  |> rows()
}

pub fn get(db: Database, id: Int) {
  "SELECT * FROM registrations WHERE id = $1"
  |> pog.query()
  |> pog.parameter(pog.int(id))
  |> pog.returning(registration_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn get_by_issuer_client_id(db: Database, issuer: String, client_id: String) {
  "SELECT * FROM registrations WHERE issuer = $1 AND client_id = $2"
  |> pog.query()
  |> pog.parameter(pog.text(issuer))
  |> pog.parameter(pog.text(client_id))
  |> pog.returning(registration_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn insert(db: Database, registration: Registration) {
  "INSERT INTO registrations (name, issuer, client_id, auth_endpoint, access_token_endpoint, keyset_url) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id"
  |> pog.query()
  |> pog.parameter(pog.text(registration.name))
  |> pog.parameter(pog.text(registration.issuer))
  |> pog.parameter(pog.text(registration.client_id))
  |> pog.parameter(pog.text(registration.auth_endpoint))
  |> pog.parameter(pog.text(registration.access_token_endpoint))
  |> pog.parameter(pog.text(registration.keyset_url))
  |> pog.returning(decode.at([0], decode.int))
  |> pog.execute(db)
  |> one()
}

pub fn update(db: Database, record: #(Int, Registration)) {
  let #(id, registration) = record

  "UPDATE registrations SET name = $1, issuer = $2, client_id = $3, auth_endpoint = $4, access_token_endpoint = $5, keyset_url = $6 WHERE id = $7"
  |> pog.query()
  |> pog.parameter(pog.text(registration.name))
  |> pog.parameter(pog.text(registration.issuer))
  |> pog.parameter(pog.text(registration.client_id))
  |> pog.parameter(pog.text(registration.auth_endpoint))
  |> pog.parameter(pog.text(registration.access_token_endpoint))
  |> pog.parameter(pog.text(registration.keyset_url))
  |> pog.parameter(pog.int(id))
  |> pog.execute(db)
  |> one()
}

pub fn delete(db: Database, id: Int) {
  "DELETE FROM registrations WHERE id = $1"
  |> pog.query()
  |> pog.parameter(pog.int(id))
  |> pog.execute(db)
  |> one()
}
