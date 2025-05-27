import gleam/dynamic/decode
import lightbulb/deployment.{type Deployment, Deployment}
import lti_example_tool/database.{type Database, type Record, Record, one, rows}
import pog

fn deployment_decoder() {
  use id <- decode.field(0, decode.int)
  use deployment_id <- decode.field(1, decode.string)
  use registration_id <- decode.field(2, decode.int)

  use created_at <- decode.field(3, pog.timestamp_decoder())
  use updated_at <- decode.field(4, pog.timestamp_decoder())

  decode.success(Record(
    id,
    created_at,
    updated_at,
    Deployment(deployment_id, registration_id),
  ))
}

pub fn all(db: Database) {
  "SELECT * FROM deployments"
  |> pog.query()
  |> pog.returning(deployment_decoder())
  |> pog.execute(db)
  |> rows()
}

pub fn get(db: Database, id: Int) {
  "SELECT * FROM deployments WHERE id = $1"
  |> pog.query()
  |> pog.parameter(pog.int(id))
  |> pog.returning(deployment_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn get_by_issuer_client_id_deployment_id(
  db: Database,
  issuer: String,
  client_id: String,
  deployment_id: String,
) {
  "SELECT * FROM deployments d
   JOIN registrations r ON d.registration_id = r.id
   WHERE r.issuer = $1 AND r.client_id = $2 AND r.deployment_id = $3"
  |> pog.query()
  |> pog.parameter(pog.text(issuer))
  |> pog.parameter(pog.text(client_id))
  |> pog.parameter(pog.text(deployment_id))
  |> pog.returning(deployment_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn get_single_deployment_by_registration_id(
  db: Database,
  registration_id: Int,
) {
  "SELECT * FROM deployments d
   WHERE d.registration_id = $1
   LIMIT 1"
  |> pog.query()
  |> pog.parameter(pog.int(registration_id))
  |> pog.returning(deployment_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn insert(db: Database, deployment: Deployment) {
  "INSERT INTO deployments (deployment_id, registration_id) VALUES ($1, $2) RETURNING id"
  |> pog.query()
  |> pog.parameter(pog.text(deployment.deployment_id))
  |> pog.parameter(pog.int(deployment.registration_id))
  |> pog.returning(decode.at([0], decode.int))
  |> pog.execute(db)
  |> one()
}

pub fn update(db: Database, record: Record(Int, Deployment)) {
  let Record(id: id, data: deployment, ..) = record

  "UPDATE deployments SET deployment_id = $1, registration_id = $2, updated_at = now() WHERE id = $3 RETURNING id, deployment_id, registration_id, created_at, updated_at"
  |> pog.query()
  |> pog.parameter(pog.text(deployment.deployment_id))
  |> pog.parameter(pog.int(deployment.registration_id))
  |> pog.parameter(pog.int(id))
  |> pog.returning(deployment_decoder())
  |> pog.execute(db)
  |> one()
}
