import gleam/erlang/process.{type Subject}
import lti/deployment.{type Deployment}
import lti/jwk.{type Jwk}
import lti/nonce.{type Nonce}
import lti/registration.{type Registration}

const call_timeout = 5000

pub type DataProviderError {
  DataProviderError(message: String)
}

pub type DataProvider =
  Subject(DataProviderMessage)

pub type DataProviderMessage {
  Shutdown
  GetActiveJwk(reply_with: Subject(Result(Jwk, Nil)))
  GetAllJwks(reply_with: Subject(List(Jwk)))
  CreateJwk(jwk: Jwk)
  CreateNonce(reply_with: Subject(Result(Nonce, Nil)))
  ValidateNonce(value: String, reply_with: Subject(Result(Nonce, Nil)))
  CleanupExpiredNonces
  CreateRegistration(
    registration: Registration,
    reply_with: Subject(Result(#(Int, Registration), Nil)),
  )
  GetRegistration(
    id: Int,
    reply_with: Subject(Result(#(Int, Registration), Nil)),
  )
  GetRegistrationBy(
    issuer: String,
    client_id: String,
    reply_with: Subject(Result(#(Int, Registration), Nil)),
  )
  GetAllRegistrations(reply_with: Subject(List(#(Int, Registration))))
  DeleteRegistration(id: Int)
  CreateDeployment(
    deployment: Deployment,
    reply_with: Subject(Result(#(Int, Deployment), Nil)),
  )
  GetDeployment(
    registration_id: Int,
    deployment_id: String,
    reply_with: Subject(Result(#(Int, Deployment), Nil)),
  )
}

pub fn cleanup(provider) {
  process.send(provider, Shutdown)
}

pub fn get_active_jwk(provider) {
  process.call(provider, GetActiveJwk, call_timeout)
}

pub fn get_all_jwks(provider) {
  process.call(provider, GetAllJwks, call_timeout)
}

pub fn create_jwk(provider, jwk) {
  process.send(provider, CreateJwk(jwk))
}

pub fn create_nonce(provider) {
  process.call(provider, CreateNonce, call_timeout)
}

pub fn validate_nonce(provider, value) {
  process.call(provider, ValidateNonce(value, _), call_timeout)
}

pub fn cleanup_expired_nonces(provider) {
  process.send(provider, CleanupExpiredNonces)
}

pub fn create_registration(provider, registration) {
  process.call(provider, CreateRegistration(registration, _), call_timeout)
}

pub fn list_registrations(provider) {
  process.call(provider, GetAllRegistrations, call_timeout)
}

pub fn get_registration(provider, id) {
  process.call(provider, GetRegistration(id, _), call_timeout)
}

pub fn get_registration_by(provider, issuer, client_id) {
  process.call(provider, GetRegistrationBy(issuer, client_id, _), call_timeout)
}

pub fn delete_registration(provider, id) {
  process.send(provider, DeleteRegistration(id))

  Ok(id)
}

pub fn create_deployment(provider, deployment) {
  process.call(provider, CreateDeployment(deployment, _), call_timeout)
}

pub fn get_deployment(provider, registration, deployment_id) {
  process.call(
    provider,
    GetDeployment(registration, deployment_id, _),
    call_timeout,
  )
}
