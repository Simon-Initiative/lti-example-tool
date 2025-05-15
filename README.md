# LTI Example Tool

An example LTI tool built with Gleam. It demonstrates how to create a simple LTI tool that
can be integrated with an LMS (Learning Management System) using the LTI (Learning Tools
Interoperability) specification.

## Quick Start

### Prerequisites

- [Docker](https://www.docker.com/) - A platform for developing, shipping, and running applications in containers.
- [Docker Compose](https://docs.docker.com/compose/) - A tool for defining and running multi-container Docker applications.

1. Clone the repository:

   ```sh
   git clone https://github.com/Simon-Initiative/lti-example-tool
   cd lti-example-tool
   ```

2. Start the application using Docker Compose:

   ```sh
   docker compose up
   ```

3. Open the application in your browser:

   ```sh
   open http://localhost:8080
   ```

4. Register the tool with your LMS or Platform using the following parameters. If you are running
   the applications somewhere other than `localhost:8080`, make sure to update the URLs accordingly.

- **Target Link URI**: `http://localhost:8080/launch`
- **Client ID**: `EXAMPLE_CLIENT_ID`
- **Login URL**: `http://localhost:8080/login`
- **Keyset URL**: `http://localhost:8080/.well-known/jwks.json`
- **Redirect URIs**: `http://localhost:8080/launch`

5. Create a Registration in the tool with the relevant parameters from your LMS or Platform.

- **Name**: `Platform Name`
- **Issuer**: `https://platform.example.edu`
- **Client ID**: `EXAMPLE_CLIENT_ID`
- **Auth Endpoint**: `https://platform.example.edu/lti/authorize`
- **Access Token Endpoint**: `https://platform.example.edu/auth/token`
- **Keyset URL**: `https://platform.example.edu/.well-known/jwks.json`
- **Deployment ID**: `some-deployment-id`

> **NOTE:** This address must be a FQDN (Fully Qualified Domain Name) and will not work with another
> `localhost` application, since the tool will be running isolated in a container. You can use `ngrok` to
> expose your localhost platform to the internet if necessary -or- if you are running the example
> tool natively using the development instructions below, then you can use `localhost` as the address.

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
