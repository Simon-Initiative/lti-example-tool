import gleam/dynamic/decode
import lti/deployment.{type Deployment, Deployment}
import lti_example_tool/database.{type Database, Record, one, rows}
import pog

fn deployment_decoder() {
  use id <- decode.field(0, decode.int)
  use deployment_id <- decode.field(1, decode.string)
  use platform_id <- decode.field(2, decode.int)

  use created_at <- decode.field(3, pog.timestamp_decoder())
  use updated_at <- decode.field(4, pog.timestamp_decoder())

  decode.success(Record(
    id,
    created_at,
    updated_at,
    Deployment(deployment_id, platform_id),
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
   JOIN platforms p ON d.platform_id = p.id
   WHERE p.issuer = $1 AND p.client_id = $2 AND d.deployment_id = $3"
  |> pog.query()
  |> pog.parameter(pog.text(issuer))
  |> pog.parameter(pog.text(client_id))
  |> pog.parameter(pog.text(deployment_id))
  |> pog.returning(deployment_decoder())
  |> pog.execute(db)
  |> one()
}

pub fn insert(db: Database, deployment: Deployment) {
  "INSERT INTO deployments (deployment_id, platform_id) VALUES ($1, $2)"
  |> pog.query()
  |> pog.parameter(pog.text(deployment.deployment_id))
  |> pog.parameter(pog.int(deployment.registration_id))
  |> pog.execute(db)
  |> one()
}
