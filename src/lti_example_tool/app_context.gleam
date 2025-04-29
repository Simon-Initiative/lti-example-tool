import lti/data_provider.{type DataProvider}
import lti/providers/memory_provider.{type MemoryProvider}
import lti_example_tool/database.{type Database}

pub type Env {
  Dev
  Test
  Prod
}

pub type AppContext {
  AppContext(
    env: Env,
    port: Int,
    secret_key_base: String,
    db: Database,
    static_directory: String,
    lti_data_provider: DataProvider,
    memory_provider: MemoryProvider,
  )
}
