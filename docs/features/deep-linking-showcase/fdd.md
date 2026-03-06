# Functional Design Document

## 1. Design Overview
- Scope covered:
  - Deep-link launch detection and branching from existing `/launch` flow.
  - Resource selection UI (3 fixed resources).
  - Deep-link response JWT + form-post generation using `lightbulb` APIs.
  - Resource-specific launch rendering for later resource launches.
- Assumptions:
  - `tool.validate_launch` already yields validated claims for both `LtiResourceLinkRequest` and `LtiDeepLinkingRequest`.
  - Existing JWK storage (`jwks.get_active_jwk`) remains the signing source.
  - Persisted deep-link selection context is acceptable in PostgreSQL for deterministic behavior in local/dev/deploy.

## 2. System Context and Boundaries
- In-scope components:
  - Router path dispatch updates in `src/lti_example_tool_web/router.gleam`.
  - Launch and deep-link selection handlers in `src/lti_example_tool_web/controllers/lti_controller.gleam`.
  - New deep-linking HTML view functions in `src/lti_example_tool_web/html/lti_html.gleam`.
  - New repository module for deep-linking request/selection context.
  - SQL migration(s) and tests.
- Out-of-scope components:
  - LMS/platform implementation details.
  - Multi-item authoring, line item authoring in deep-link response, and non-`ltiResourceLink` item types.

## 3. Architecture
- High-level flow:
  1. Platform sends launch to `POST /launch`.
  2. Tool validates with `tool.validate_launch`.
  3. Controller inspects LTI message type claim.
  4. If `LtiDeepLinkingRequest`:
     - Decode settings with `deep_linking.get_deep_linking_settings`.
     - Create short-lived one-time deep-link context record.
     - Render resource picker form.
  5. User submits selected resource to `POST /deep-linking/respond`.
  6. Controller consumes context, builds `ltiResourceLink` content item for selected resource, signs response JWT with `deep_linking.build_response_jwt`, returns auto-submit HTML via `deep_linking.build_response_form_post`.
  7. If `LtiResourceLinkRequest`, continue normal launch path and render selected resource context when present.
- Module responsibilities:
  - `router.gleam`: add explicit path match for deep-link response endpoint.
  - `lti_controller.gleam`:
    - extract message type helper.
    - deep-link launch branch and selection submit action.
    - existing resource-link launch branch remains for AGS/NRPS and launch display.
  - `lti_html.gleam`:
    - render deep-link resource chooser page.
    - render optional resource context section in launch details or dedicated resource view.
  - `deep_linking_contexts.gleam` (new): create/get/consume/expire context records.
- AppContext wiring impact:
  - No new top-level context fields required; reuse existing DB + provider access.
- Runtime/supervision impact:
  - No new OTP process required; request/response path only.

## 4. Data Design
- Schema and migration changes:
  - Add table `deep_linking_contexts` (or equivalent name) with one-time context records.
  - Suggested columns:
    - `id` (PK)
    - `context_token` (unique string, random)
    - `iss` (text)
    - `aud` (text)
    - `deployment_id` (text)
    - `deep_link_return_url` (text)
    - `request_data` (nullable text)
    - `accept_types` (text/json)
    - `accept_multiple` (bool nullable)
    - `accept_lineitem` (bool nullable)
    - `created_at` (timestamp)
    - `expires_at` (timestamp)
    - `consumed_at` (nullable timestamp)
- Data lifecycle:
  - Insert on deep-link launch.
  - Consume exactly once on selection submit.
  - Reject if expired or previously consumed.
  - Periodic cleanup is optional; on-demand cleanup can be added later.
- Migration/backfill strategy:
  - Forward-only migration; no backfill required.
  - Rollback drops table if needed.

## 5. Interfaces and Contracts
- Internal APIs:
  - `lti_controller.validate_launch/2` gains message-type routing.
  - New `lti_controller.respond_deep_linking/2` endpoint function.
  - New repository API:
    - `create_context(db, context)`
    - `consume_context(db, context_token)`
    - `get_valid_context(db, context_token)` (optional split)
- External APIs/webhooks:
  - Existing LTI launch `POST /launch`.
  - New deep-link submit endpoint: `POST /deep-linking/respond`.
- Event/message formats:
  - Input claims use standard LTI + deep-linking claims from validated launch.
  - Response form must post hidden field named `JWT` to platform return URL.

## 6. Runtime Behavior
- Request/runtime model:
  - Synchronous HTTP handling via existing Wisp/Mist flow.
- Concurrency model:
  - Context consumption should be atomic to prevent replay/double-submit.
- Failure handling/retries:
  - Any decode/signing/context failure returns safe HTML error page.
  - Internal reason logged with `logger.error_meta`.
- Timeouts/idempotency:
  - Context TTL configurable constant (for example 10 minutes).
  - Repeated submit with same context returns invalid/expired message.

## 7. Security and Compliance
- AuthN/AuthZ impact:
  - Keep trust boundary at `tool.validate_launch`; never process deep-linking from unvalidated claims.
- Data protection:
  - Store minimal context necessary; avoid storing full ID token/JWT.
  - Do not emit sensitive claim material in user-visible output.
- Audit/logging requirements:
  - Log: deep-link launch detected, context creation, selection accepted, JWT build failure, context reject reason.

## 8. Observability and Operations
- Metrics:
  - Deep-link launch count.
  - Deep-link response success/failure count.
  - Context rejection count by reason (`expired`, `consumed`, `missing`, `invalid_resource`).
- Logs:
  - Structured metadata including issuer, deployment_id, selected resource id, and error category.
- Alerts/runbooks:
  - Not required for local example app; include troubleshooting notes in docs/comments for failed deep-link responses.

## 9. Testing Strategy
- Unit:
  - Resource selection mapping (`Resource 1/2/3` -> content item custom payload).
  - Message type extraction helpers.
- Integration (`wisp/simulate`, DB, LTI flows):
  - `LtiDeepLinkingRequest` launch returns selection page.
  - Valid selection returns HTML form with `JWT` and deep-link form id.
  - Consumed/expired context returns safe error response.
  - Non-deep-link launch path still renders launch details and AGS/NRPS sections as before.
- Contract:
  - Verify response content item type is `ltiResourceLink` and request `data` echo behavior remains standards-compliant through `lightbulb`.
- End-to-end:
  - Manual run against an LMS/platform configured for deep linking.

## 10. Open Questions
- Should resource launch display be a dedicated page per resource or a section within existing `launch_details` page?
- Should deep-link context cleanup be done lazily on reads or via explicit maintenance command?
- Should selectable resources be hardcoded constants or loaded from configuration for future demos?
