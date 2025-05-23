import lightbulb/providers.{Providers}
import lightbulb/providers/httpc_provider
import lti_example_tool/app_context.{type AppContext, AppContext}
import lti_example_tool/config
import lti_example_tool/database
import lti_example_tool/database/migrate_and_seed
import lti_example_tool/db_provider
import lti_example_tool/env.{Dev}
import lti_example_tool/feature_flags
import lti_example_tool/utils/devtools
import wisp

pub fn setup() -> AppContext {
  let env = config.env()
  let port = config.port()
  let static_directory = static_directory()
  let secret_key_base = config.secret_key_base(env)

  migrate_and_seed.initialize_db()

  let assert Ok(db) = database.connect()

  let assert Ok(lti_data_provider) = db_provider.data_provider(db)

  env.exec(env, Dev, fn() { devtools.start() })

  let http_provider = httpc_provider.http_provider()

  let feature_flags = feature_flags.load()

  AppContext(
    env: env,
    port: port,
    secret_key_base: secret_key_base,
    db: db,
    static_directory: static_directory,
    providers: Providers(lti_data_provider, http_provider),
    feature_flags: feature_flags,
  )
}

pub fn static_directory() -> String {
  // The priv directory is where we store non-Gleam and non-Erlang files,
  // including static assets to be served.
  // This function returns an absolute path and works both in development and in
  // production after compilation.
  let assert Ok(priv_directory) = wisp.priv_directory("lti_example_tool")

  priv_directory <> "/static"
}
