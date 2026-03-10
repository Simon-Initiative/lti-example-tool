import gleam/bit_array
import gleam/crypto
import lti_example_tool/config

pub type AdminAuth {
  Disabled
  Enabled(password_hash: BitArray)
}

pub fn load() -> AdminAuth {
  case config.admin_password() {
    Ok(password) if password != "" -> enabled(password)

    _ -> Disabled
  }
}

pub fn enabled(password: String) -> AdminAuth {
  Enabled(hash_password(password))
}

pub fn is_configured(auth: AdminAuth) -> Bool {
  case auth {
    Enabled(_) -> True
    Disabled -> False
  }
}

pub fn verify_password(auth: AdminAuth, password: String) -> Bool {
  case auth {
    Enabled(password_hash:) ->
      crypto.secure_compare(hash_password(password), password_hash)

    Disabled -> False
  }
}

pub fn session_value(auth: AdminAuth) -> Result(String, Nil) {
  case auth {
    Enabled(password_hash:) -> Ok(build_session_value(password_hash))
    Disabled -> Error(Nil)
  }
}

fn hash_password(password: String) -> BitArray {
  crypto.hash(crypto.Sha256, <<password:utf8>>)
}

fn build_session_value(password_hash: BitArray) -> String {
  crypto.hash(crypto.Sha256, <<"admin-session:":utf8, password_hash:bits>>)
  |> bit_array.base16_encode
}
