import gleam/dynamic/decode
import gleam/result
import lti/jwk.{type Jwk, Jwk}
import lti_example_tool/database.{type Database, type Record, Record, one, rows}
import pog

fn jwk_decoder() -> decode.Decoder(Record(String, Jwk)) {
  use kid <- decode.field(0, decode.string)
  use kty <- decode.field(1, decode.string)
  use alg <- decode.field(2, decode.string)
  use use_ <- decode.field(3, decode.string)
  use n <- decode.field(4, decode.string)
  use e <- decode.field(5, decode.string)

  use created_at <- decode.field(6, pog.timestamp_decoder())
  use updated_at <- decode.field(7, pog.timestamp_decoder())

  decode.success(Record(
    id: kid,
    created_at: created_at,
    updated_at: updated_at,
    data: Jwk(kid: kid, kty: kty, alg: alg, use_: use_, n: n, e: e),
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
  "INSERT INTO jwks (kid, kty, alg, use, n, e) VALUES ($1, $2, $3, $4, $5, $6) RETURNING kid"
  |> pog.query()
  |> pog.parameter(pog.text(jwk.kid))
  |> pog.parameter(pog.text(jwk.kty))
  |> pog.parameter(pog.text(jwk.alg))
  |> pog.parameter(pog.text(jwk.use_))
  |> pog.parameter(pog.text(jwk.n))
  |> pog.parameter(pog.text(jwk.e))
  |> pog.returning(decode.at([0], decode.string))
  |> pog.execute(db)
  |> one()
}

pub fn update(db: Database, jwk: Record(String, Jwk)) {
  "UPDATE jwks SET kty = $1, alg = $2, use = $3, n = $4, e = $5 WHERE kid = $6"
  |> pog.query()
  |> pog.parameter(pog.text(jwk.data.kty))
  |> pog.parameter(pog.text(jwk.data.alg))
  |> pog.parameter(pog.text(jwk.data.use_))
  |> pog.parameter(pog.text(jwk.data.n))
  |> pog.parameter(pog.text(jwk.data.e))
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
