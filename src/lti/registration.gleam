pub type Registration {
  Registration(
    id: Int,
    issuer: String,
    client_id: String,
    key_set_url: String,
    auth_token_url: String,
    auth_login_url: String,
    auth_server: String,
    tool_jwk_id: Int,
  )
}
