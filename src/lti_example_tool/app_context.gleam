import lightbulb/providers.{type Providers}
import lti_example_tool/database.{type Database}
import lti_example_tool/env.{type Env}
import lti_example_tool/feature_flags.{type FeatureFlags}

pub type AppContext {
  AppContext(
    env: Env,
    port: Int,
    secret_key_base: String,
    db: Database,
    static_directory: String,
    providers: Providers,
    feature_flags: List(FeatureFlags),
  )
}
