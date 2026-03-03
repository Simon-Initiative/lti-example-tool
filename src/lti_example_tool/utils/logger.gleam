import envoy
import gleam/result
import gleam/string
import logging

pub type Level {
  Emergency
  Alert
  Critical
  Error
  Warning
  Notice
  Info
  Debug
}

fn to_logging_level(level: Level) -> logging.LogLevel {
  case level {
    Emergency -> logging.Emergency
    Alert -> logging.Alert
    Critical -> logging.Critical
    Error -> logging.Error
    Warning -> logging.Warning
    Notice -> logging.Notice
    Info -> logging.Info
    Debug -> logging.Debug
  }
}

pub fn configure() -> Nil {
  logging.configure()
}

pub fn configure_backend() -> Nil {
  configure()
}

pub fn set_level(level: Level) -> Nil {
  logging.set_level(to_logging_level(level))
}

pub fn test_log_level() -> Level {
  case envoy.get("TEST_LOG_LEVEL") |> result.map(string.lowercase) {
    Ok("debug") -> Debug
    Ok("info") -> Info
    Ok("notice") -> Notice
    Ok("warning") -> Warning
    Ok("error") -> Error
    Ok("critical") -> Critical
    Ok("alert") -> Alert
    Ok("emergency") -> Emergency
    _ -> Emergency
  }
}

pub fn configure_for_tests() -> Nil {
  configure()
  set_level(test_log_level())
}

pub fn log(level: Level, message: String) -> Nil {
  logging.log(to_logging_level(level), message)
}

pub fn log_meta(level: Level, message: String, meta: a) -> Nil {
  log(level, message <> "\n" <> string.inspect(meta))
}

pub fn info(message: String) -> Nil {
  log(Info, message)
}

pub fn info_meta(message: String, meta: a) -> Nil {
  log_meta(Info, message, meta)
}

pub fn warn(message: String) -> Nil {
  log(Warning, message)
}

pub fn warn_meta(message: String, meta: a) -> Nil {
  log_meta(Warning, message, meta)
}

pub fn error(message: String) -> Nil {
  log(Error, message)
}

pub fn error_meta(message: String, meta: a) -> Nil {
  log_meta(Error, message, meta)
}

pub fn debug(message: String) -> Nil {
  log(Debug, message)
}

pub fn debug_meta(message: String, meta: a) -> Nil {
  log_meta(Debug, message, meta)
}
