import lti/data_provider.{type DataProvider}
import lti_example_tool/database.{type Database}

pub type Env {
  Dev
  Test
  Prod
}

pub type AppContext {
  AppContext(
    env: Env,
    port: Int,
    secret_key_base: String,
    db: Database,
    static_directory: String,
    lti_data_provider: DataProvider,
  )
}

pub fn env_exec(current: Env, target: Env, cb: fn() -> Nil) -> Nil {
  case current == target {
    True -> cb()
    False -> Nil
  }
}
