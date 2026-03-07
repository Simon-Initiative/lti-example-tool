import gleam/result
import lightbulb/errors.{NonceExpired, NonceInvalid}
import lightbulb/providers/data_provider.{
  type DataProvider, DataProvider, ProviderActiveJwkNotFound,
  ProviderCreateNonceFailed, ProviderDeploymentNotFound,
  ProviderRegistrationNotFound,
}
import lti_example_tool/database.{type Database}
import lti_example_tool/deployments
import lti_example_tool/jwks
import lti_example_tool/nonces
import lti_example_tool/oidc_states
import lti_example_tool/registrations

pub fn data_provider(db: Database) -> Result(DataProvider, String) {
  Ok(
    DataProvider(
      create_nonce: fn() { create_nonce(db) },
      validate_nonce: fn(nonce) { validate_nonce(db, nonce) },
      save_login_context: fn(context) {
        oidc_states.save_login_context(db, context)
      },
      get_login_context: fn(state) { oidc_states.get_login_context(db, state) },
      consume_login_context: fn(state) {
        oidc_states.consume_login_context(db, state)
      },
      get_registration: fn(issuer, client_id) {
        get_registration(db, issuer, client_id)
      },
      get_deployment: fn(issuer, client_id, deployment_id) {
        get_deployment(db, issuer, client_id, deployment_id)
      },
      get_active_jwk: fn() { get_active_jwk(db) },
    ),
  )
}

fn create_nonce(db: Database) {
  nonces.create(db)
  |> result.replace_error(ProviderCreateNonceFailed)
}

fn validate_nonce(db: Database, nonce: String) {
  case nonces.validate_nonce(db, nonce) {
    Ok(_) -> Ok(Nil)
    Error("Invalid nonce") -> Error(NonceInvalid)
    Error("Expired nonce") -> Error(NonceExpired)
    Error(_) -> Error(NonceInvalid)
  }
}

fn get_registration(db: Database, issuer: String, client_id: String) {
  registrations.get_by_issuer_client_id(db, issuer, client_id)
  |> result.replace_error(ProviderRegistrationNotFound)
  |> result.map(fn(record) { record.data })
}

fn get_deployment(
  db: Database,
  issuer: String,
  client_id: String,
  deployment_id: String,
) {
  deployments.get_by_issuer_client_id_deployment_id(
    db,
    issuer,
    client_id,
    deployment_id,
  )
  |> result.replace_error(ProviderDeploymentNotFound)
  |> result.map(fn(record) { record.data })
}

fn get_active_jwk(db: Database) {
  case jwks.get_active_jwk(db) {
    Ok(jwk) -> Ok(jwk.data)
    Error(_) -> Error(ProviderActiveJwkNotFound)
  }
}
