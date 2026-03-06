# Product Requirements Document

## 1. Feature Summary
- Name: Deep Linking Showcase
- Last Updated: 2026-03-05
- Status: Draft

This feature adds an end-to-end Deep Linking 2.0 demonstration to the tool so developers and instructors can verify a standards-aligned deep-link launch and return flow. The tool will present three fixed example resources and generate a signed deep-linking response using `lightbulb`. The selected resource context will then be visible in subsequent resource-link launches.

## 2. Goals and Non-Goals
### Goals
- Implement tool-side handling for `LtiDeepLinkingRequest` launches.
- Present a simple resource picker in the tool with exactly three options: `Resource 1`, `Resource 2`, `Resource 3`.
- Return a valid signed `LtiDeepLinkingResponse` using `lightbulb/deep_linking` and `lightbulb/deep_linking/content_item`.
- Support subsequent launch behavior for selected resources, so the tool can identify which resource was chosen via deep linking.
- Keep the implementation aligned with LTI 1.3 and Deep Linking 2.0 expectations and existing app patterns.

### Non-Goals
- Building a generic authoring UI for arbitrary content items.
- Supporting every deep-link content item type (`file`, `html`, `image`, etc.) in this feature.
- Implementing full instructor content management (CRUD) for deep-linked resources.
- Reworking AGS/NRPS behavior beyond compatibility with deep-linked resource launches.

## 3. Users and Primary Use Cases
- Personas:
  - LMS instructor configuring a tool placement through deep linking.
  - Tool developer validating deep-linking behavior locally and in certification-style checks.
- User stories:
  - Instructor starts deep-link launch from LMS and sees a resource picker in the tool.
  - Instructor selects one resource and the tool auto-posts a deep-link response JWT back to LMS.
  - LMS later launches the selected deep-linked placement; tool identifies resource context and displays resource-specific launch details.

## 4. Functional Requirements
1. The `/launch` handling must distinguish LTI message types after `tool.validate_launch` and branch to deep-linking flow when message type is `LtiDeepLinkingRequest`.
2. For deep-linking launches, the tool must render a selection UI with options: `Resource 1`, `Resource 2`, `Resource 3`.
3. The tool must persist enough deep-link request context to safely process the resource selection submission (deep-link settings, launch claims needed for response, expiration metadata).
4. The tool must expose a selection submit endpoint that accepts one resource choice and returns an HTML form-post payload generated from `lightbulb/deep_linking.build_response_form_post`.
5. The deep-link response JWT must be built with `lightbulb/deep_linking.build_response_jwt`, using decoded settings and active JWK from provider storage.
6. Returned content item must be `ltiResourceLink` and include a deterministic mapping to selected example resource (e.g., custom claim entry like `resource_id`).
7. For non-deep-link launches (`LtiResourceLinkRequest`), the tool must continue to validate launch and render launch content; if selected resource context exists, display which resource was launched.
8. Invalid or expired deep-link selection context must produce a safe error page and server-side log entry.
9. Existing `/launch` behavior for AGS/NRPS demos must remain functional.

## 5. Non-Functional Requirements
- Reliability:
  - Deep-link selection submission must fail safely when context is missing/expired.
  - No uncaught exceptions for malformed deep-linking claims.
- Performance:
  - Selection page render and response generation should complete within normal request latency bounds for current app (<500ms excluding platform/network).
- Security/Compliance:
  - Validate launch token/signature via existing `tool.validate_launch` path.
  - Respect deep-link settings constraints (`accept_types`, `accept_multiple`, `accept_lineitem`) through `lightbulb` validators.
  - Do not expose internal claim/jwt signing details in user-facing errors.
- Observability:
  - Add structured logs for deep-link launch detected, selection accepted/rejected, response build success/failure.

## 6. Success Metrics
- Product metrics:
  - Deep-link launch -> resource selection -> successful response post flow can be completed for all 3 resources in local/dev validation.
- Technical metrics:
  - Automated tests cover: deep-link launch rendering, valid selection handling, invalid/expired context failure, and resource-specific launch rendering.
  - `gleam test` passes with new tests.

## 7. Dependencies and Constraints
- Internal dependencies:
  - `lti_controller.gleam`, `router.gleam`, `lti_html.gleam`.
  - Data provider and JWK retrieval paths already used for launch/security.
- External dependencies:
  - `lightbulb/deep_linking` and `lightbulb/deep_linking/content_item` APIs.
  - LMS/platform deep-linking request behavior.
- Constraints:
  - Must preserve existing explicit router/controller pattern and `Result`-driven flow.
  - Must remain compatible with current DB migration and test setup approach.

## 8. Risks and Mitigations
- Risk: Deep-link request context handling is vulnerable to replay or stale submissions.
- Mitigation: Use short-lived persisted selection context with one-time consume semantics and explicit expiration checks.

- Risk: LMS/platform-specific expectations differ for resource data mapping.
- Mitigation: Use standards-compliant `ltiResourceLink` item and include minimal deterministic custom field (`resource_id`) while keeping behavior simple.

- Risk: New launch branching could regress existing AGS/NRPS paths.
- Mitigation: Keep non-deep-link path intact and add regression tests for current launch flows.

## 9. Acceptance Criteria
1. Given a valid `LtiDeepLinkingRequest` launch, when `/launch` is processed, then the response page shows selectable options `Resource 1`, `Resource 2`, and `Resource 3`.
2. Given a valid deep-linking launch context, when the user selects one resource, then the tool returns an auto-submit form posting a signed `JWT` to `deep_link_return_url`.
3. Given missing/expired/consumed deep-linking context, when selection is submitted, then the tool returns a safe error response and logs the internal reason.
4. Given a standard resource-link launch after deep-link placement, when the launch includes selected resource context, then the tool renders launch details that identify the chosen resource.
5. Given existing AGS/NRPS launches, when launched through current flow, then behavior remains unchanged and tests continue to pass.
