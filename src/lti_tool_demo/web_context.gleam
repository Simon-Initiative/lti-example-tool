import lti_tool_demo/session.{type SessionConfig}

pub type WebContext {
  WebContext(
    port: Int,
    secret_key_base: String,
    static_directory: String,
    session_config: SessionConfig,
  )
}
