import gleam/otp/actor
import gleam/otp/static_supervisor.{type Supervisor} as supervisor
import lightbulb/providers.{Providers}
import lightbulb/providers/httpc_provider
import lti_example_tool/app_context.{type AppContext, AppContext}
import lti_example_tool/config
import lti_example_tool/database
import lti_example_tool/database/migrate
import lti_example_tool/db_provider
import lti_example_tool/feature_flags
import pog
import wisp

pub fn setup() -> AppContext {
  let env = config.env()
  let port = config.port()
  let static_directory = static_directory()
  let secret_key_base = config.secret_key_base(env)

  let db_pool_name = "lti_example_tool_db_pool"
  let assert Ok(db_config) = database.get_config(db_pool_name)
  let assert Ok(_) = start_application_supervisor(db_config)

  let db = pog.named_connection(db_config.pool_name)

  // Ensure the database is initialized
  migrate.maybe_initialize_db(db_config)

  let assert Ok(lti_data_provider) = db_provider.data_provider(db)

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

fn start_application_supervisor(
  db_config: pog.Config,
) -> actor.StartResult(Supervisor) {
  let db_supervisor =
    db_config
    |> pog.pool_size(15)
    |> pog.supervised

  supervisor.new(supervisor.RestForOne)
  |> supervisor.add(db_supervisor)
  // |> supervisor.add(other)
  // |> supervisor.add(application)
  // |> supervisor.add(children)
  |> supervisor.start
}
