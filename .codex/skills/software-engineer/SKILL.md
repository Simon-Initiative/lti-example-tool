---
name: software-engineer
description: Implement features and bugfixes for the Gleam-based LTI 1.3 example tool lti-example-tool. Use when asked to debug, investigate, implement, or ship product changes; for larger features, drive execution from docs/features/<feature>/prd.md, fdd.md, and plan.md.
---

# Software Engineer

## Overview

Execute pragmatic, production-quality feature and bugfix work for this repository's Gleam + Erlang/OTP + Wisp/Mist LTI 1.3 tool stack.

## Core Workflow

1. Gather context.

- Read the prompt, related code paths, tests, and recent diffs.
- Start with the relevant modules:
  - app startup/context: `src/lti_example_tool.gleam`, `src/lti_example_tool/application.gleam`
  - web routing/middleware: `src/lti_example_tool_web/router.gleam`, `src/lti_example_tool_web/web.gleam`
  - LTI endpoints: `src/lti_example_tool_web/controllers/lti_controller.gleam`
  - registration flows: `src/lti_example_tool_web/controllers/registration_controller.gleam`
  - persistence/repositories: `src/lti_example_tool/{database,registrations,deployments,jwks,nonces}.gleam`
- Identify affected domains: LTI launch/auth, AGS/NRPS services, registration/deployment management, and DB-backed security state.

2. Classify the work size.

- Use `investigation` for root-cause analysis or uncertain requirements.
- Use `small-change` for isolated bugfixes or narrowly scoped feature updates.
- Use `feature-delivery` for larger functionality that should follow a feature spec.

3. Select execution path.

- `investigation`: Reproduce, isolate, form hypothesis, validate with evidence, propose minimal fix.
- `small-change`: Implement smallest safe patch, preserve behavior outside scope, add/update tests.
- `feature-delivery`: Read spec files in order:
  1. `docs/features/<feature>/prd.md`
  2. `docs/features/<feature>/fdd.md`
  3. `docs/features/<feature>/plan.md`
     Treat `prd.md` as product source of truth, `fdd.md` as design constraints, `plan.md` as execution sequence.

4. Implement with stack discipline.

- Keep Gleam types and module interfaces explicit; prefer small composable functions and `Result`-driven error flow.
- Keep routing and method checks explicit in router/controllers (no hidden routing DSL behavior).
- Reuse existing repository modules instead of ad-hoc SQL in controllers.
- Preserve backward compatibility for web contracts unless the spec explicitly changes them.
- For LTI/LMS behavior, enforce launch/auth correctness (OIDC state/nonce, claims, issuer/client/deployment matching), and AGS/NRPS semantics.
- Keep user-facing errors safe; log implementation details with `logger.error_meta`.
- If data model changes are required:
  1. Add migration SQL in `priv/repo/migrations/`.
  2. Update decoders/repository modules.
  3. Update seeds handling if needed (`src/lti_example_tool/seeds.gleam`, `seeds.yml` schema assumptions).

5. Verify before handoff.

- Run the narrowest relevant tests first, then broader suites as needed.
- Validate error paths, edge cases, and integration assumptions.
- Confirm docs/config/migrations are updated when behavior changes.
- Project validation commands (prefer this order when relevant):
  1. `gleam build`
  2. `gleam run -m lti_example_tool/database/migrate test.setup`
  3. `gleam test`
  4. `gleam format --check src test`

6. Report clearly.

- State what changed, why, and what was validated.
- List assumptions, risks, and follow-up tasks if scope was constrained.

## Delivery Rules

- Prefer small, reviewable commits and minimal blast radius.
- Avoid speculative refactors unless required to complete the task safely.
- Preserve repository conventions:
  - explicit route matching in `router.gleam`
  - middleware behavior in `web.gleam`
  - server-rendered HTML via Nakai modules under `src/lti_example_tool_web/html*`
- Escalate contradictions between spec files; do not silently guess.

## References

- Use [references/execution-checklists.md](references/execution-checklists.md) for repeatable checklists.
- Keep `AGENTS.md` as the project-specific source of truth for architecture and operational commands.
