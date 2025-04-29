import gleam/result
import lti/data_provider.{type DataProvider, DataProvider}
import lti_example_tool/database.{type Database}
import lti_example_tool/deployments
import lti_example_tool/nonces
import lti_example_tool/platforms

pub fn data_provider(db: Database) -> Result(DataProvider, String) {
  Ok(
    DataProvider(
      create_nonce: fn() { nonces.create(db) },
      validate_nonce: fn(nonce) { nonces.validate_nonce(db, nonce) },
      get_registration: fn(issuer, client_id) {
        platforms.get_by_issuer_client_id(db, issuer, client_id)
        |> result.replace_error("Failed to get registration")
        |> result.map(fn(record) { record.data })
      },
      get_deployment: fn(issuer, client_id, deployment_id) {
        deployments.get_by_issuer_client_id_deployment_id(
          db,
          issuer,
          client_id,
          deployment_id,
        )
        |> result.replace_error("Failed to get deployment")
        |> result.map(fn(record) { record.data })
      },
    ),
  )
}
