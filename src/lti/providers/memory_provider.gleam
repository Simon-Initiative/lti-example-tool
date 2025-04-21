import birl
import gleam/erlang/process
import gleam/function.{identity}
import gleam/list
import gleam/order.{Lt}
import gleam/otp/actor.{type StartError, Spec}
import lti/data_provider.{type DataProvider, type DataProviderMessage}
import lti/deployment.{type Deployment}
import lti/jwk.{type Jwk}
import lti/nonce.{type Nonce}
import lti/registration.{type Registration}

type State {
  State(
    jwks: List(Jwk),
    nonces: List(Nonce),
    registrations: List(Registration),
    deployments: List(Deployment),
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

    data_provider.CreateNonce(nonce) -> {
      actor.continue(State(..state, nonces: [nonce, ..state.nonces]))
    }

    data_provider.GetNonce(value, reply_with) -> {
      let result = list.find(state.nonces, fn(nonce) { nonce.value == value })

      actor.send(reply_with, result)

      actor.continue(state)
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

    data_provider.CreateRegistration(registration) -> {
      actor.continue(
        State(..state, registrations: [registration, ..state.registrations]),
      )
    }

    data_provider.GetRegistration(issuer, client_id, reply_with) -> {
      let result =
        list.find(state.registrations, fn(registration) {
          registration.issuer == issuer && registration.client_id == client_id
        })

      actor.send(reply_with, result)

      actor.continue(state)
    }

    data_provider.CreateDeployment(deployment) -> {
      actor.continue(
        State(..state, deployments: [deployment, ..state.deployments]),
      )
    }

    data_provider.GetDeployment(registration, deployment_id, reply_with) -> {
      let result =
        list.find(state.deployments, fn(deployment) {
          deployment.registration_id == registration.id
          && deployment.id == deployment_id
        })

      actor.send(reply_with, result)

      actor.continue(state)
    }
  }
}

pub fn start() -> Result(DataProvider, StartError) {
  let init = fn() {
    let self = process.new_subject()

    let state = State(jwks: [], nonces: [], registrations: [], deployments: [])

    let selector = process.selecting(process.new_selector(), self, identity)

    actor.Ready(state, selector)
  }

  let call_timeout = 5000

  actor.start_spec(Spec(init, call_timeout, handle_message))
}
