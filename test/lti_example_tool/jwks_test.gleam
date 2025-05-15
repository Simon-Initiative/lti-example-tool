import gleam/result
import gleeunit/should
import lti/jwk
import lti_example_tool/config
import lti_example_tool/jwks
import pog

fn test_db() {
  config.database_url()
  |> pog.url_config()
  |> result.map(fn(db_config) {
    pog.connect(
      pog.Config(..db_config, database: db_config.database <> "_test"),
    )
  })
}

pub fn active_jwk_test() {
  let assert Ok(db) = test_db()
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
