import gleam/erlang/process
import lti_example_tool/utils/cmd
import lti_example_tool/utils/logger

pub fn start() {
  process.spawn(fn() {
    logger.info("Starting tailwind development watcher...")

    let assert Ok(_) =
      cmd.exec(
        "npx",
        [
          "tailwindcss", "-i", "./app.css", "-o", "priv/static/app.css",
          "--watch",
        ],
        in: ".",
      )
  })

  Nil
}
