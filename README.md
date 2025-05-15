# LTI Example Tool

An example LTI tool built with Gleam. It demonstrates how to create a simple LTI tool that
can be integrated with an LMS (Learning Management System) using the LTI (Learning Tools
Interoperability) specification.

## Development

### Prerequisites

- [asdf](https://asdf-vm.com/) - A version manager for multiple programming languages.
- [Gleam](https://gleam.run/) - The programming language used for this project. Can be installed via
  `asdf`.
- [Node.js](https://nodejs.org/) - The JavaScript runtime used for tailwind styles. Can be installed via
  `asdf`.
- [PostgreSQL](https://www.postgresql.org/) - The database used for this project.
- [watchexec](https://github.com/watchexec/watchexec) - A tool to watch for file changes. Available
  via `brew install watchexec` on macOS.

### Getting Started

1. Clone the repository:
   ```sh
   git clone https://github.com/Simon-Initiative/lti-example-tool
   cd lti-example-tool
   ```
2. Install tooling
   ```sh
   asdf install
   ```
3. Install npm dependencies:
   ```sh
   npm install
   ```
   This will install the tailwind used for styles.
4. Install the dependencies:
   ```sh
   gleam deps download
   ```
5. Initialize the database:
   ```sh
   gleam run -m lti_example_tool/database/migrate_and_seed setup
   ```
6. Copy the example seeds file and edit it for automatic platform configuration:
   ```sh
   cp seeds.example.yml seeds.yml
   ```
7. Run the server and watch for changes:
   ```sh
   watchexec --stop-signal=SIGKILL -r -e gleam gleam run
   ```
8. Open the application in your browser:
   ```sh
   open http://localhost:8080
   ```

### Useful Commands

```sh
# Run the project
gleam run

# Run the project and watch for changes
watchexec --stop-signal=SIGKILL -r -e gleam gleam run

# Reset the database
gleam run -m lti_example_tool/database/migrate_and_seed reset

# Run the tests
gleam test
```
