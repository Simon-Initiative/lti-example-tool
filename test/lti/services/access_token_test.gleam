import gleam/option.{Some}
import gleeunit/should
import lti/jwk
import lti/providers/memory_provider
import lti/registration.{Registration}
import lti/services/access_token
import lti/services/ags
import lti/services/nrps

pub fn create_client_assertion_test() {
  let assert Ok(jwk) = jwk.generate()

  echo access_token.create_client_assertion(
    jwk,
    "https://example.com",
    "some_client_id",
    Some("https://example.com/auth"),
  )
}

pub fn active_jwk_test() {
  let assert Ok(memory_provider) = memory_provider.start()
  let assert Ok(lti_data_provider) =
    memory_provider.data_provider(memory_provider)

  let assert Ok(jwk) = jwk.generate()

  memory_provider.create_jwk(memory_provider, jwk)

  let assert Ok(#(_, registration)) =
    memory_provider.create_registration(
      memory_provider,
      Registration(
        name: "Example Registration",
        issuer: "http://example.com",
        client_id: "SOME_CLIENT_ID",
        auth_endpoint: "http://example.com/lti/authorize_redirect",
        access_token_endpoint: "http://example.com/auth/token",
        keyset_url: "http://example.com/jwks.json",
      ),
    )

  let scopes = [
    ags.lineitem_scope_url,
    ags.result_readonly_scope_url,
    ags.scores_scope_url,
    nrps.context_membership_readonly_claim_url,
  ]

  echo access_token.fetch_access_token(lti_data_provider, registration, scopes)
}
