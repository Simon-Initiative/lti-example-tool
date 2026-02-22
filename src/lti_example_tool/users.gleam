import gleam/dynamic/decode
import lti_example_tool/database.{type Database, type Record, Record, one}
import pog

pub type User {
  User(
    sub: String,
    name: String,
    email: String,
    issuer: String,
    audience: String,
    roles: String,
    context_title: String,
  )
}

fn user_decoder() -> decode.Decoder(Record(Int, User)) {
  use id <- decode.field(0, decode.int)
  use sub <- decode.field(1, decode.string)
  use name <- decode.field(2, decode.string)
  use email <- decode.field(3, decode.string)
  use issuer <- decode.field(4, decode.string)
  use audience <- decode.field(5, decode.string)
  use roles <- decode.field(6, decode.string)
  use context_title <- decode.field(7, decode.string)
  use created_at <- decode.field(8, pog.timestamp_decoder())
  use updated_at <- decode.field(9, pog.timestamp_decoder())

  decode.success(Record(
    id: id,
    created_at: created_at,
    updated_at: updated_at,
    data: User(
      sub: sub,
      name: name,
      email: email,
      issuer: issuer,
      audience: audience,
      roles: roles,
      context_title: context_title,
    ),
  ))
}

pub fn upsert(db: Database, user: User) -> Result(Record(Int, User), _) {
  "INSERT INTO users (sub, name, email, issuer, audience, roles, context_title) VALUES ($1, $2, $3, $4, $5, $6, $7)
   ON CONFLICT (sub, issuer, audience)
   DO UPDATE SET
     name = EXCLUDED.name,
     email = EXCLUDED.email,
     roles = EXCLUDED.roles,
     context_title = EXCLUDED.context_title,
     updated_at = NOW()
   RETURNING id, sub, name, email, issuer, audience, roles, context_title, created_at, updated_at"
  |> pog.query()
  |> pog.parameter(pog.text(user.sub))
  |> pog.parameter(pog.text(user.name))
  |> pog.parameter(pog.text(user.email))
  |> pog.parameter(pog.text(user.issuer))
  |> pog.parameter(pog.text(user.audience))
  |> pog.parameter(pog.text(user.roles))
  |> pog.parameter(pog.text(user.context_title))
  |> pog.returning(user_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn get(db: Database, id: Int) -> Result(Record(Int, User), _) {
  "SELECT id, sub, name, email, issuer, audience, roles, context_title, created_at, updated_at FROM users WHERE id = $1"
  |> pog.query()
  |> pog.parameter(pog.int(id))
  |> pog.returning(user_decoder())
  |> pog.execute(db)
  |> one()
}
