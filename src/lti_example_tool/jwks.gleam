import gleam/dynamic/decode
import gleam/result
import lightbulb/jwk.{type Jwk, Jwk}
import lti_example_tool/database.{type Database, type Record, Record, one, rows}
import pog

fn jwk_decoder() -> decode.Decoder(Record(String, Jwk)) {
  use kid <- decode.field(0, decode.string)
  use typ <- decode.field(1, decode.string)
  use alg <- decode.field(2, decode.string)
  use pem <- decode.field(3, decode.string)

  use created_at <- decode.field(4, pog.timestamp_decoder())
  use updated_at <- decode.field(5, pog.timestamp_decoder())

  decode.success(Record(
    id: kid,
    created_at: created_at,
    updated_at: updated_at,
    data: Jwk(kid, typ, alg, pem),
  ))
}

pub fn all(db: Database) {
  "SELECT * FROM jwks"
  |> pog.query()
  |> pog.returning(jwk_decoder())
  |> pog.execute(db)
  |> rows()
}

pub fn get(db: Database, kid: String) {
  "SELECT * FROM jwks WHERE kid = $1"
  |> pog.query()
  |> pog.parameter(pog.text(kid))
  |> pog.returning(jwk_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn insert(db: Database, jwk: Jwk) {
  "INSERT INTO jwks (kid, typ, alg, pem) VALUES ($1, $2, $3, $4) RETURNING kid"
  |> pog.query()
  |> pog.parameter(pog.text(jwk.kid))
  |> pog.parameter(pog.text(jwk.typ))
  |> pog.parameter(pog.text(jwk.alg))
  |> pog.parameter(pog.text(jwk.pem))
  |> pog.returning(decode.at([0], decode.string))
  |> pog.execute(db)
  |> one()
}

pub fn update(db: Database, jwk: Record(String, Jwk)) {
  "UPDATE jwks SET typ = $1, alg = $2, pem = $3 WHERE kid = $6"
  |> pog.query()
  |> pog.parameter(pog.text(jwk.data.typ))
  |> pog.parameter(pog.text(jwk.data.alg))
  |> pog.parameter(pog.text(jwk.data.pem))
  |> pog.parameter(pog.text(jwk.id))
  |> pog.execute(db)
}

pub fn delete(db: Database, kid: String) {
  "DELETE FROM jwks WHERE kid = $1"
  |> pog.query()
  |> pog.parameter(pog.text(kid))
  |> pog.execute(db)
}

pub fn set_active_jwk(db: Database, kid: String) {
  database.transaction(db, fn(db) {
    use _ <- result.try(
      "DELETE FROM active_jwk"
      |> pog.query()
      |> pog.execute(db)
      |> result.map_error(database.QueryError),
    )

    "INSERT INTO active_jwk (kid) VALUES ($1)"
    |> pog.query()
    |> pog.parameter(pog.text(kid))
    |> pog.execute(db)
    |> result.map_error(database.QueryError)
  })
}

pub fn get_active_jwk(db: Database) {
  "SELECT jwks.* FROM active_jwk JOIN jwks ON active_jwk.kid = jwks.kid"
  |> pog.query()
  |> pog.returning(jwk_decoder())
  |> pog.execute(db)
  |> one()
}
