import birl.{type Time}

pub type Nonce {
  Nonce(nonce: String, expires_at: Time)
}
