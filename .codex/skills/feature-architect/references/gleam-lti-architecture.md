# Gleam LTI Architecture Guardrails

Use this reference to keep designs aligned with this repository's Gleam + BEAM patterns.

## 1. System Decomposition

- Organize by domain modules and web boundaries already present in the app.
- Keep routing explicit in `router.gleam`; avoid hidden DSL-like behavior.
- Keep controllers focused on transport concerns; move persistence/state access into repository/provider modules.

## 2. Runtime and Process Model

- Treat app startup as a first-class design area: config load, DB initialization, migrations, and AppContext wiring in `application.gleam`.
- Prefer `Result`-driven control flow for recoverable failures.
- Keep failure handling explicit and user-safe; log internal details with structured metadata.

## 3. LTI 1.3 Domain Concerns

- Preserve OIDC login/launch invariants: state, nonce, issuer, client_id, deployment_id, and token validation paths.
- Design features to fit LTI endpoints and extension services (AGS, NRPS, JWKS) without weakening existing security controls.
- Define idempotency and replay protections whenever launch-adjacent flows are touched.

## 4. Persistence and Data Integrity

- Model data changes through SQL migrations in `priv/repo/migrations`.
- Update repository decoders and data adapters alongside schema changes.
- Keep transactional boundaries explicit in database/repository modules rather than controllers.
- Include rollback and seed/update implications when altering registration, deployment, nonce, token, or JWK data.

## 5. Web Layer and UX

- Keep route/method checks explicit and easy to audit.
- Reuse existing HTML view patterns (Nakai/Tailwind) and JSON response conventions.
- Keep user-facing errors safe and actionable; do not leak secrets or internal stack details.

## 6. Observability and Operability

- Ensure major flows emit enough logs for debugging launch and token issues.
- Define concrete metrics for success/failure paths where behavior changes are introduced.
- Document operational checks for migrations, seed validity, and feature-flag behavior.

## 7. Security

- Protect key material, nonce/state data, and token records.
- Preserve secure cookie/session assumptions for OIDC and launch validation.
- Validate authorization checks at service/domain boundaries, not only at HTTP edges.

## 8. Testing Expectations

- Unit-test domain and parsing/validation logic.
- Add integration tests for routes/controllers and DB-backed behavior.
- Use migration + seed setup in tests when schema/data dependencies exist.
- Verify regressions in LTI launch flows and security-critical paths.

## 9. Architecture Decision Quality

For each major choice, document:
- Decision
- Alternatives considered
- Tradeoffs
- Operational impact
- Migration and rollback implications
