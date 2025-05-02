import gleam/option.{Some}
import gleeunit/should
import lti/jwk
import lti/services/access_token
import lti_example_tool/database

pub fn active_jwk_test() {
  let db = database.connect("lti_example_tool_test")
  let assert Ok(jwk) = jwk.generate()

  echo access_token.create_client_assertion(
    jwk,
    "https://example.com",
    "some_client_id",
    Some("https://example.com/auth"),
  )
}
