# AGENTS.md

## Project Overview

`lti-example-tool` is a Gleam-based LTI 1.3 tool provider application. It exposes endpoints for OIDC login, LTI launch validation, AGS score submission, NRPS memberships, JWKS publishing, and platform registration management.

Primary goals of the app:

- Demonstrate LTI 1.3 tool/provider integration patterns.
- Provide a working local + Docker development workflow.
- Store platform registrations/deployments and cryptographic state in PostgreSQL.

## Architecture

Request and runtime flow:

1. `src/lti_example_tool.gleam` starts Mist + Wisp and builds app context via `application.setup()`.
2. `src/lti_example_tool/application.gleam`:
   - Loads env/config.
   - Ensures DB exists and is migrated/seeded.
   - Opens DB connection pool.
   - Builds LTI data provider.
   - Starts Tailwind watcher in `Dev`.
3. `src/lti_example_tool_web/router.gleam` dispatches requests by path segments.
4. `src/lti_example_tool_web/web.gleam` applies middleware (logging, crash rescue, static files, HEAD handling).
5. Controllers render HTML with Nakai (`src/lti_example_tool_web/html*`) or JSON for JWKS.

Design style:

- No router DSL; explicit pattern matching on path/method.
- `Result`-driven control flow (`use ... <- result.try(...)` style).
- Lightweight server-rendered HTML + Tailwind CSS.

## Key Components

- App startup: `src/lti_example_tool.gleam`, `src/lti_example_tool/application.gleam`
- Request routing: `src/lti_example_tool_web/router.gleam`
- Middleware + URL helpers: `src/lti_example_tool_web/web.gleam`
- LTI endpoints: `src/lti_example_tool_web/controllers/lti_controller.gleam`
- Registration CRUD: `src/lti_example_tool_web/controllers/registration_controller.gleam`
- DB connection + transaction helpers: `src/lti_example_tool/database.gleam`
- Migrations/seeding CLI: `src/lti_example_tool/database/migrate_and_seed.gleam`
- Seeds loader (`seeds.yml`): `src/lti_example_tool/seeds.gleam`
- LTI data provider adapters: `src/lti_example_tool/db_provider.gleam`
- Security data stores:
  - JWKs: `src/lti_example_tool/jwks.gleam`
  - Nonces: `src/lti_example_tool/nonces.gleam`
- Feature flags: `src/lti_example_tool/feature_flags.gleam`
- Logger + FFI: `src/lti_example_tool/utils/logger.gleam`, `src/lti_example_tool_ffi.erl`

## Development Setup

### Prerequisites

- Tool versions (from `.tool-versions`)
- PostgreSQL
- `watchexec` for local auto-reload

### Local Setup

1. `asdf install`
2. `npm install`
3. `gleam deps download`
4. `cp seeds.example.yml seeds.yml` (edit values)
5. `gleam run -m lti_example_tool/database/migrate_and_seed setup`
6. `watchexec --stop-signal=SIGKILL -r -e gleam gleam run`
7. Open `http://localhost:8080`

### Docker Setup

- `docker compose up`
- App: `http://localhost:8080`
- Postgres: `localhost:5432` (`postgres/postgres`)

## Database Setup

Default DB URL fallback:

- `postgresql://postgres:postgres@localhost:5432/lti_example_tool`

Core DB initialization behavior:

- `application.setup()` calls `initialize_db()` on startup.
- If DB does not exist, setup creates DB, runs migrations, seeds initial JWK + optional seeds file registrations.

Migrations currently create:

- `migrations`
- `registrations`
- `deployments`
- `nonces`
- `jwks`
- `active_jwk`

## Key Technologies & Patterns

- Language/runtime: Gleam on Erlang/OTP.
- HTTP stack: Wisp + Mist.
- LTI domain library: `lightbulb` (git dependency on `master`).
- DB: PostgreSQL via `pog`.
- Forms: `formal`.
- HTML rendering: `nakai`.
- YAML parsing for seeds: `glaml`.
- CSS: Tailwind (`app.css` -> `priv/static/app.css`).

Patterns to preserve:

- Prefer explicit `Result` error paths over exceptions.
- Keep routing and method checks explicit in controllers.
- Use existing repository modules (`registrations`, `deployments`, `jwks`, `nonces`) instead of ad-hoc SQL in controllers.
- Keep user-facing errors safe; log internals with `logger.error_meta`.

## Common Development Tasks

- Run app: `gleam run`
- Run app with local auto-reload: `watchexec --stop-signal=SIGKILL -r -e gleam gleam run`
- Build app: `gleam build`
- Build CSS once: `npm run tailwind:build`
- Watch CSS: `npm run tailwind:watch`
- Run tests: `gleam test`
- Format check: `gleam format --check src test`
- Format code: `gleam format src test`
- Full clean: `npm run clean`

## Database Operations Quick Reference

- Setup DB: `gleam run -m lti_example_tool/database/migrate_and_seed setup`
- Migrate only: `gleam run -m lti_example_tool/database/migrate_and_seed migrate`
- Seed only: `gleam run -m lti_example_tool/database/migrate_and_seed seed`
- Reset DB: `gleam run -m lti_example_tool/database/migrate_and_seed reset`
- Setup test DB: `gleam run -m lti_example_tool/database/migrate_and_seed test.setup`
- Reset test DB: `gleam run -m lti_example_tool/database/migrate_and_seed test.reset`

Useful SQL checks:

- `SELECT * FROM migrations ORDER BY inserted_at DESC;`
- `SELECT * FROM registrations;`
- `SELECT * FROM deployments;`
- `SELECT * FROM nonces;`
- `SELECT * FROM active_jwk;`

## Repo Structure

- `src/lti_example_tool.gleam`: main entrypoint
- `src/lti_example_tool/`: domain, data, app setup, and core modules
- `src/lti_example_tool_web/`: web layer modules (router, middleware, controllers, HTML views)
- `src/lti_example_tool/database/`: DB tooling modules
- `test/`: gleeunit tests
- `priv/static/`: built static assets
- `app.css`: Tailwind input
- `seeds.example.yml`, `seeds.yml`: seed data
- `Dockerfile`, `docker-compose.yml`: container workflows
- `.github/workflows/`: CI (test + package)

## Endpoint Map

- `GET /` home page
- `POST /login` OIDC login
- `POST /launch` launch validation
- `POST /score` AGS score submit
- `POST /memberships` NRPS memberships fetch
- `GET /.well-known/jwks.json` public keys
- `GET|POST /registrations...` registration CRUD + access token utilities

## Debugging Tips

- Logs are simplified via FFI logger config (`level: message` style).
- Missing `SECRET_KEY_BASE` in `Prod` warns and defaults to insecure `"change_me"`.
- `PUBLIC_URL` controls URL generation; default is localhost with detected port.
- `/registrations` UI can be disabled by feature flags (`ENABLE_REGISTRATIONS`).
- OIDC failures are often state-cookie related; ensure secure cookie behavior matches your deployment/proxy.
- Seed loading errors usually come from invalid/missing `seeds.yml` fields.
- Ensure platform `issuer + client_id + deployment_id` combination matches stored registration/deployment rows.

## CI, Quality, and Release Notes

- CI workflow starts Postgres, runs build, `test.setup`, `gleam test`, and format check.
- Container image publish workflow pushes `ghcr.io/simon-initiative/lti-example-tool`.
- Keep changes CI-safe by running locally:
  - `gleam build`
  - `gleam run -m lti_example_tool/database/migrate_and_seed test.setup`
  - `gleam test`
  - `gleam format --check src test`

## Agentic Coding Playbook

When making changes:

1. Read the relevant controller + repository module first.
2. If data model changes are required, add migration(s) in `migrate_and_seed.gleam`, then update repository decoders and tests.
3. Keep AppContext wiring centralized in `application.gleam`.
4. Prefer adding/adjusting tests in `test/` for new behavior.
5. Verify with build + tests + formatting before finalizing.

When adding a new endpoint:

1. Add route match in `src/lti_example_tool_web/router.gleam`.
2. Add controller action in `src/lti_example_tool_web/controllers/*`.
3. Reuse middleware conventions in `src/lti_example_tool_web/web.gleam`.
4. Add/update view templates in `src/lti_example_tool_web/html/` when returning HTML.
5. Add integration-style test via `wisp/simulate`.

When diagnosing DB errors:

1. Confirm `DATABASE_URL`.
2. Run `... migrate_and_seed setup` or `reset`.
3. Check migrations table and key domain tables.
4. Validate seed YAML shape if using seed-driven registrations.

## Additional Resources

- Project intro/setup: `README.md`
- Dependency/runtime config: `gleam.toml`, `manifest.toml`
- LTI flow implementation references:
  - `src/lti_example_tool_web/controllers/lti_controller.gleam`
  - `src/lti_example_tool/db_provider.gleam`
- CI reference: `.github/workflows/test.yml`
