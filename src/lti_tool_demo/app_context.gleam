import lti/data_provider.{type DataProvider}
import lti_tool_demo/database.{type Database}
import lti_tool_demo/session.{type SessionConfig}

pub type AppContext {
  AppContext(
    port: Int,
    secret_key_base: String,
    db: Database,
    static_directory: String,
    session_config: SessionConfig,
    lti_data_provider: DataProvider,
  )
}
