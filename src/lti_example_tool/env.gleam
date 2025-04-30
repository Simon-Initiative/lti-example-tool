pub type Env {
  Dev
  Test
  Prod
}

/// Executes the given callback if the current environment matches the target environment.
/// This is useful for running code only in specific environments, such as development or
/// production.
pub fn exec(current: Env, target: Env, cb: fn() -> Nil) -> Nil {
  case current == target {
    True -> cb()
    False -> Nil
  }
}
