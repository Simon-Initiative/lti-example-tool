import lti/deployment.{type Deployment}
import lti/nonce.{type Nonce}
import lti/registration.{type Registration}

pub type DataProvider {
  DataProvider(
    create_nonce: fn() -> Result(Nonce, String),
    validate_nonce: fn(String) -> Result(Nil, String),
    get_registration: fn(String, String) -> Result(Registration, String),
    get_deployment: fn(String, String, String) -> Result(Deployment, String),
  )
}

pub fn create_nonce(provider: DataProvider) -> Result(Nonce, String) {
  provider.create_nonce()
}

pub fn validate_nonce(
  provider: DataProvider,
  value: String,
) -> Result(Nil, String) {
  provider.validate_nonce(value)
}

pub fn get_registration(
  provider: DataProvider,
  issuer: String,
  client_id: String,
) -> Result(Registration, String) {
  provider.get_registration(issuer, client_id)
}

pub fn get_deployment(
  provider: DataProvider,
  issuer: String,
  client_id: String,
  deployment_id: String,
) -> Result(Deployment, String) {
  provider.get_deployment(issuer, client_id, deployment_id)
}
