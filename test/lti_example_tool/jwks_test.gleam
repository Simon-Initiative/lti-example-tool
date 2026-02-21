import gleam/result
import gleam/erlang/process
import gleeunit/should
import lightbulb/jwk
import lti_example_tool/config
import lti_example_tool/jwks
import pog

fn test_db() {
  pog.url_config(
    process.new_name("lti_example_tool_test_db"),
    config.database_url(),
  )
  |> result.try(fn(db_config) {
    pog.start(
      pog.Config(..db_config, database: db_config.database <> "_test"),
    )
    |> result.map(fn(started) { started.data })
    |> result.replace_error(Nil)
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
