import lti/providers.{type Providers}
import lti_example_tool/database.{type Database}
import lti_example_tool/env.{type Env}

pub type AppContext {
  AppContext(
    env: Env,
    port: Int,
    secret_key_base: String,
    db: Database,
    static_directory: String,
    providers: Providers,
  )
}
