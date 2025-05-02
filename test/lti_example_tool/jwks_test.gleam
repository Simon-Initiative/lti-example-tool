import gleeunit/should
import lti/jwk
import lti_example_tool/database
import lti_example_tool/jwks

pub fn active_jwk_test() {
  let db = database.connect("lti_example_tool_test")
  let assert Ok(jwk) = jwk.generate()

  jwks.insert(db, jwk)
  |> should.be_ok()

  jwks.set_active_jwk(db, jwk.kid)
  |> should.be_ok()

  let active_jwk_result = jwks.get_active_jwk(db)

  active_jwk_result
  |> should.be_ok()

  let assert Ok(active_jwk) = active_jwk_result

  { active_jwk.id == jwk.kid }
  |> should.be_true()
}
