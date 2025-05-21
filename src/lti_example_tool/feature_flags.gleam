import gleam/list
import gleam/string
import lti_example_tool/config

pub type FeatureFlags {
  Registrations
}

pub fn load() -> List(FeatureFlags) {
  let feature_flags = [#("ENABLE_REGISTRATIONS", "TRUE", Registrations)]

  list.fold(feature_flags, [], fn(acc, flag) {
    let #(env_var, default_value, feature) = flag
    let value = config.env_var(env_var, default_value)

    case string.lowercase(value) {
      "true" -> [feature, ..acc]
      _ -> acc
    }
  })
}
