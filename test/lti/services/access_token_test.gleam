import gleam/http
import gleam/http/response
import gleeunit/should
import lti/jwk
import lti/providers
import lti/providers/http_mock_provider
import lti/providers/memory_provider
import lti/registration.{Registration}
import lti/services/access_token.{AccessToken}
import lti/services/ags
import lti/services/nrps

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

  let providers =
    providers.Providers(
      data: lti_data_provider,
      http: http_mock_provider.http_provider(fn(req) {
        req.method
        |> should.equal(http.Post)

        response.new(200)
        |> response.set_body(
          "
        {
          \"access_token\": \"SOME_ACCESS_TOKEN\",
          \"token_type\": \"Bearer\",
          \"expires_in\": 3600,
          \"scope\": \"some scopes\"
        }
        ",
        )
        |> Ok
      }),
    )

  access_token.fetch_access_token(providers, registration, scopes)
  |> should.equal(
    Ok(AccessToken("SOME_ACCESS_TOKEN", "Bearer", 3600, "some scopes")),
  )
}
