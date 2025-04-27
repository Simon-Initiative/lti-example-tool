import birl
import birl/duration
import gleam/erlang/process
import gleam/function.{identity}
import gleam/list
import gleam/order.{Lt}
import gleam/otp/actor.{type StartError, Spec}
import ids/uuid
import lti/data_provider.{type DataProvider, type DataProviderMessage}
import lti/deployment.{type Deployment}
import lti/jwk.{type Jwk}
import lti/nonce.{type Nonce, Nonce}
import lti/providers/memory_provider/tables.{type Table}
import lti/registration.{type Registration}
import lti_tool_demo/utils/common.{try_with}
import lti_tool_demo/utils/logger

type State {
  State(
    jwks: List(Jwk),
    nonces: List(Nonce),
    registrations: Table(Registration),
    deployments: Table(Deployment),
  )
}

fn handle_message(
  message: DataProviderMessage,
  state: State,
) -> actor.Next(DataProviderMessage, State) {
  case message {
    data_provider.Shutdown -> actor.Stop(process.Normal)

    data_provider.GetActiveJwk(reply_with) -> {
      case state.jwks {
        [] -> actor.send(reply_with, Error(Nil))
        [jwk, ..] -> actor.send(reply_with, Ok(jwk))
      }

      actor.continue(state)
    }

    data_provider.GetAllJwks(reply_with) -> {
      actor.send(reply_with, state.jwks)

      actor.continue(state)
    }

    data_provider.CreateJwk(jwk) -> {
      actor.continue(State(..state, jwks: [jwk, ..state.jwks]))
    }

    data_provider.CreateNonce(reply_with) -> {
      use nonce <- try_with(uuid.generate_v4(), or_else: fn(e) {
        logger.error_meta("Failed to generate nonce", e)

        actor.send(reply_with, Error(Nil))

        actor.continue(state)
      })

      let nonce = Nonce(nonce, birl.now() |> birl.add(duration.minutes(5)))

      actor.send(reply_with, Ok(nonce))

      actor.continue(State(..state, nonces: [nonce, ..state.nonces]))
    }

    data_provider.ValidateNonce(value, reply_with) -> {
      let result = list.find(state.nonces, fn(nonce) { nonce.nonce == value })

      actor.send(reply_with, result)

      // remove the nonce from the list so it can't be reused
      let nonces = list.filter(state.nonces, fn(nonce) { nonce.nonce != value })

      actor.continue(State(..state, nonces: nonces))
    }

    data_provider.CleanupExpiredNonces -> {
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

    data_provider.CreateRegistration(registration, reply_with) -> {
      let #(updated_registrations, record) =
        tables.insert(state.registrations, registration)

      actor.send(reply_with, Ok(record))

      actor.continue(State(..state, registrations: updated_registrations))
    }

    data_provider.GetRegistration(issuer, client_id, reply_with) -> {
      let record =
        tables.get_by(state.registrations, fn(registration) {
          registration.issuer == issuer && registration.client_id == client_id
        })

      actor.send(reply_with, record)

      actor.continue(state)
    }

    data_provider.CreateDeployment(deployment, reply_with) -> {
      let #(updated_deployments, record) =
        tables.insert(state.deployments, deployment)

      actor.send(reply_with, Ok(record))

      actor.continue(State(..state, deployments: updated_deployments))
    }

    data_provider.GetDeployment(registration_id, deployment_id, reply_with) -> {
      let record =
        tables.get_by(state.deployments, fn(deployment) {
          deployment.registration_id == registration_id
          && deployment.deployment_id == deployment_id
        })

      actor.send(reply_with, record)

      actor.continue(state)
    }
  }
}

pub fn start() -> Result(DataProvider, StartError) {
  let init = fn() {
    let self = process.new_subject()

    let state =
      State(
        jwks: [],
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
