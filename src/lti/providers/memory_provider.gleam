import birl
import birl/duration
import gleam/erlang/process.{type Subject}
import gleam/function.{identity}
import gleam/list
import gleam/order.{Lt}
import gleam/otp/actor.{type StartError, Spec}
import gleam/pair
import gleam/result
import ids/uuid
import lti/data_provider.{type DataProvider, DataProvider}
import lti/deployment.{type Deployment}
import lti/jwk.{type Jwk}
import lti/nonce.{type Nonce, Nonce}
import lti/providers/memory_provider/tables.{type Table}
import lti/registration.{type Registration}
import lti_example_tool/utils/common.{try_with}
import lti_example_tool/utils/logger

const call_timeout = 5000

pub type MemoryProvider =
  Subject(Message)

type State {
  State(
    dispatch: fn(Message) -> Nil,
    jwks: List(Jwk),
    active_jwk_kid: String,
    nonces: List(Nonce),
    registrations: Table(Registration),
    deployments: Table(Deployment),
  )
}

pub type Message {
  Shutdown
  GetActiveJwk(reply_with: Subject(Result(Jwk, Nil)))
  GetAllJwks(reply_with: Subject(List(Jwk)))
  CreateJwk(jwk: Jwk)
  SetActiveJwk(kid: String)
  CreateNonce(reply_with: Subject(Result(Nonce, Nil)))
  ValidateNonce(value: String, reply_with: Subject(Result(Nil, Nil)))
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
    issuer: String,
    client_id: String,
    deployment_id: String,
    reply_with: Subject(Result(#(Int, Deployment), String)),
  )
}

fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
  // The dispatch function is a safe way to send messages to the actor. Messages will be
  // processed in the order they are received after the current operation is completed.
  let State(dispatch, ..) = state

  case message {
    Shutdown -> actor.Stop(process.Normal)

    GetActiveJwk(reply_with) -> {
      case state.jwks {
        [] -> actor.send(reply_with, Error(Nil))
        [jwk, ..] -> actor.send(reply_with, Ok(jwk))
      }

      actor.continue(state)
    }

    GetAllJwks(reply_with) -> {
      actor.send(reply_with, state.jwks)

      actor.continue(state)
    }

    CreateJwk(jwk) -> {
      // if this is the first JWK, set it as the active JWK
      case state.jwks == [] {
        True -> dispatch(SetActiveJwk(jwk.kid))
        False -> Nil
      }

      actor.continue(State(..state, jwks: [jwk, ..state.jwks]))
    }

    SetActiveJwk(kid) -> {
      actor.continue(State(..state, active_jwk_kid: kid))
    }

    CreateNonce(reply_with) -> {
      use nonce <- try_with(uuid.generate_v4(), or_else: fn(e) {
        logger.error_meta("Failed to generate nonce", e)

        actor.send(reply_with, Error(Nil))

        actor.continue(state)
      })

      let nonce = Nonce(nonce, birl.now() |> birl.add(duration.minutes(5)))

      actor.send(reply_with, Ok(nonce))

      actor.continue(State(..state, nonces: [nonce, ..state.nonces]))
    }

    ValidateNonce(value, reply_with) -> {
      let result = list.find(state.nonces, fn(nonce) { nonce.nonce == value })

      actor.send(reply_with, result |> result.map(fn(_) { Nil }))

      // remove the nonce from the list so it can't be reused
      let nonces = list.filter(state.nonces, fn(nonce) { nonce.nonce != value })

      actor.continue(State(..state, nonces: nonces))
    }

    CleanupExpiredNonces -> {
      let now = birl.now()

      let nonces =
        list.filter(state.nonces, fn(nonce) {
          case birl.compare(now, nonce.expires_at) {
            Lt -> True
            _ -> False
          }
        })

      actor.continue(State(..state, nonces: nonces))
    }

    CreateRegistration(registration, reply_with) -> {
      let #(updated_registrations, record) =
        tables.insert(state.registrations, registration)

      actor.send(reply_with, Ok(record))

      actor.continue(State(..state, registrations: updated_registrations))
    }

    GetRegistration(id, reply_with) -> {
      let record = tables.get(state.registrations, id)

      actor.send(reply_with, record)

      actor.continue(state)
    }

    GetRegistrationBy(issuer, client_id, reply_with) -> {
      let record =
        tables.get_by(state.registrations, fn(registration) {
          registration.issuer == issuer && registration.client_id == client_id
        })

      actor.send(reply_with, record)

      actor.continue(state)
    }

    GetAllRegistrations(reply_with) -> {
      actor.send(reply_with, state.registrations.records)

      actor.continue(state)
    }

    DeleteRegistration(id) -> {
      let updated_registrations = tables.delete(state.registrations, id)

      actor.continue(State(..state, registrations: updated_registrations))
    }

    CreateDeployment(deployment, reply_with) -> {
      let #(updated_deployments, record) =
        tables.insert(state.deployments, deployment)

      actor.send(reply_with, Ok(record))

      actor.continue(State(..state, deployments: updated_deployments))
    }

    GetDeployment(issuer, client_id, deployment_id, reply_with) -> {
      use #(registration_id, _registration) <- try_with(
        tables.get_by(state.registrations, fn(registration) {
          registration.issuer == issuer && registration.client_id == client_id
        }),
        or_else: fn(e) {
          logger.error_meta("Failed to get registration", e)

          actor.send(reply_with, Error("Registration not found"))

          actor.continue(state)
        },
      )

      let record =
        tables.get_by(state.deployments, fn(deployment) {
          deployment.registration_id == registration_id
          && deployment.deployment_id == deployment_id
        })
        |> result.replace_error("Deployment not found")

      actor.send(reply_with, record)

      actor.continue(state)
    }
  }
}

pub fn start() -> Result(MemoryProvider, StartError) {
  let init = fn() {
    let self = process.new_subject()

    let state =
      State(
        dispatch: process.send(self, _),
        jwks: [],
        active_jwk_kid: "",
        nonces: [],
        registrations: tables.new(),
        deployments: tables.new(),
      )

    let selector = process.selecting(process.new_selector(), self, identity)

    actor.Ready(state, selector)
  }

  let call_timeout = 5000

  actor.start_spec(Spec(init, call_timeout, handle_message))
}

pub fn cleanup(actor) {
  process.send(actor, Shutdown)
}

pub fn data_provider(memory_provider) -> Result(DataProvider, String) {
  Ok(
    DataProvider(
      create_nonce: fn() {
        create_nonce(memory_provider)
        |> result.replace_error("Failed to create nonce")
      },
      validate_nonce: fn(nonce) {
        validate_nonce(memory_provider, nonce)
        |> result.replace_error("Failed to validate nonce")
      },
      get_registration: fn(issuer, client_id) {
        get_registration_by(memory_provider, issuer, client_id)
        |> result.map(pair.second)
        |> result.replace_error("Failed to get registration")
      },
      get_deployment: fn(issuer, client_id, deployment_id) {
        get_deployment(memory_provider, issuer, client_id, deployment_id)
        |> result.map(pair.second)
        |> result.replace_error("Failed to get deployment")
      },
      get_active_jwk: fn() {
        get_active_jwk(memory_provider)
        |> result.replace_error("Failed to get active JWK")
      },
    ),
  )
}

pub fn get_active_jwk(actor) {
  process.call(actor, GetActiveJwk, call_timeout)
}

pub fn get_all_jwks(actor) {
  process.call(actor, GetAllJwks, call_timeout)
}

pub fn create_jwk(actor, jwk) {
  process.send(actor, CreateJwk(jwk))
}

pub fn create_nonce(actor) {
  process.call(actor, CreateNonce, call_timeout)
}

pub fn validate_nonce(actor, value) {
  process.call(actor, ValidateNonce(value, _), call_timeout)
}

pub fn cleanup_expired_nonces(actor) {
  process.send(actor, CleanupExpiredNonces)
}

pub fn create_registration(actor, registration) {
  process.call(actor, CreateRegistration(registration, _), call_timeout)
}

pub fn list_registrations(actor) {
  process.call(actor, GetAllRegistrations, call_timeout)
}

pub fn get_registration(actor, id) {
  process.call(actor, GetRegistration(id, _), call_timeout)
}

pub fn get_registration_by(actor, issuer, client_id) {
  process.call(actor, GetRegistrationBy(issuer, client_id, _), call_timeout)
}

pub fn delete_registration(actor, id) {
  process.send(actor, DeleteRegistration(id))

  Ok(id)
}

pub fn create_deployment(actor, deployment) {
  process.call(actor, CreateDeployment(deployment, _), call_timeout)
}

pub fn get_deployment(actor, issuer, client_id, deployment_id) {
  process.call(
    actor,
    GetDeployment(issuer, client_id, deployment_id, _),
    call_timeout,
  )
}
