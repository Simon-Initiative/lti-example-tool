import birl.{type Time}

pub type Nonce {
  Nonce(id: Int, value: String, created_at: Time, expires_at: Time)
}
