import gleam/erlang/process.{type Subject}
import gleam/otp/actor
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
  CreateNonce(nonce: Nonce)
  GetNonce(value: String, reply_with: Subject(Result(Nonce, Nil)))
  CleanupExpiredNonces
  CreateRegistration(registration: Registration)
  GetRegistration(
    issuer: String,
    client_id: String,
    reply_with: Subject(Result(Registration, Nil)),
  )
  CreateDeployment(deployment: Deployment)
  GetDeployment(
    registration: Registration,
    deployment_id: String,
    reply_with: Subject(Result(Deployment, Nil)),
  )
}

pub fn cleanup(provider) {
  actor.send(provider, Shutdown)
}

pub fn get_active_jwk(provider) {
  process.call(provider, GetActiveJwk, call_timeout)
}

pub fn get_all_jwks(provider) {
  process.call(provider, GetAllJwks, call_timeout)
}

pub fn create_jwk(provider, jwk) {
  actor.send(provider, CreateJwk(jwk))
}

pub fn create_nonce(provider, nonce) {
  actor.send(provider, CreateNonce(nonce))
}

pub fn get_nonce(provider, value) {
  process.call(provider, GetNonce(value, _), call_timeout)
}

pub fn cleanup_expired_nonces(provider) {
  actor.send(provider, CleanupExpiredNonces)
}

pub fn create_registration(provider, registration) {
  actor.send(provider, CreateRegistration(registration))
}

pub fn get_registration(provider, issuer, client_id) {
  process.call(provider, GetRegistration(issuer, client_id, _), call_timeout)
}

pub fn create_deployment(provider, deployment) {
  actor.send(provider, CreateDeployment(deployment))
}

pub fn get_deployment(provider, registration, deployment_id) {
  process.call(
    provider,
    GetDeployment(registration, deployment_id, _),
    call_timeout,
  )
}
