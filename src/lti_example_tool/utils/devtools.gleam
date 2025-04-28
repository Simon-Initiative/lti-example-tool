import gleam/otp/task
import lti_example_tool/app_context
import lti_example_tool/utils/cmd
import lti_example_tool/utils/logger

pub fn maybe_start_devtools(env: app_context.Env) {
  let _ = case env {
    app_context.Dev -> {
      logger.info("Starting tailwind development watcher...")

      task.async(fn() {
        let assert Ok(_) =
          cmd.exec(
            "npx",
            [
              "tailwindcss", "-i", "./app.css", "-o", "priv/static/app.css",
              "--watch",
            ],
            in: ".",
          )

        Nil
      })

      True
    }
    _ -> False
  }
}
