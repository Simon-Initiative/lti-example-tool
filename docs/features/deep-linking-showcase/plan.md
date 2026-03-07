# Implementation Plan

## Phase 0 - Alignment and Readiness
### Deliverables
- Approved deep-linking scope and architecture baseline for this repository.

### Tasks
- [x] Confirm endpoint contract for deep-link selection submit (`POST /deep-linking/respond`).
- [x] Confirm deep-link context persistence model and TTL policy.
- [x] Confirm chosen mapping format for selected example resources (`resource_id` custom value).
- [x] Confirm acceptance criteria and test matrix for deep-linking and existing launch regression.

### Verification
- [x] PRD and FDD approved.
- [x] Open questions resolved or explicitly deferred.

## Phase 1 - Data and Domain Foundations
### Deliverables
- Persistent deep-link context storage and repository API.

### Tasks
- [x] Add migration for `deep_linking_contexts` table with one-time consume + expiration fields.
- [x] Implement new repository module for create/get/consume deep-link contexts.
- [x] Add validation helpers for resource ids (`resource-1`, `resource-2`, `resource-3`).
- [ ] Add basic unit tests for repository behavior and expiration/consume semantics.

### Verification
- [x] Migration applies cleanly with existing migration flow.
- [ ] Repository tests validate missing/expired/consumed behavior.

## Phase 2 - Deep-Link Launch and Response Flow
### Deliverables
- End-to-end deep-link request handling and signed response generation.

### Tasks
- [x] Update router with explicit deep-link response endpoint route.
- [x] Refactor `/launch` handler to branch on message type claim.
- [x] Implement deep-link request branch: decode settings, create context, render resource chooser.
- [x] Implement deep-link selection submit action: consume context, build `ltiResourceLink`, sign JWT with `deep_linking.build_response_jwt`, return form-post HTML.
- [x] Implement safe error handling/logging for invalid message type, settings decode failure, context errors, and JWT build failures.

### Verification
- [ ] Integration tests cover deep-link request rendering and successful response posting payload.
- [ ] Integration tests cover invalid/expired/consumed context failures.

## Phase 3 - Resource Launch Experience and Regression Safety
### Deliverables
- Resource-specific launch rendering and preserved AGS/NRPS behavior.

### Tasks
- [x] Extend launch rendering to surface selected resource context for deep-linked launches.
- [x] Keep existing AGS/NRPS sections functional for resource-link launches.
- [ ] Add regression tests for non-deep-link launch behavior.
- [x] Add/adjust UI text to make deep-link demo flow explicit in rendered pages.

### Verification
- [ ] Tests confirm resource-specific context is displayed when available.
- [x] Existing launch-related tests continue passing without behavior regressions.

## Phase 4 - Hardening, Documentation, and Manual QA
### Deliverables
- Production-like readiness for the example scenario and documented validation steps.

### Tasks
- [x] Add structured log entries for deep-link lifecycle events and failures.
- [x] Document local manual test flow for deep-linking in project docs or feature notes.
- [ ] Run full validation commands (`gleam build`, DB test setup, `gleam test`, format check).
- [ ] Perform manual QA with a platform deep-link launch and verify all three resources.

### Verification
- [ ] Manual QA confirms `Resource 1`, `Resource 2`, and `Resource 3` each produce valid deep-link responses.
- [ ] Manual QA confirms follow-up launches show correct selected resource context.
- [ ] Final sign-off notes recorded in feature folder.

## PR Grouping (Recommended)
- PR Group 1: Phase 1 (migration + repository + foundational tests).
- PR Group 2: Phase 2 (launch branching + deep-link response endpoint + integration tests).
- PR Group 3: Phase 3 and Phase 4 (resource UX, regression hardening, docs, manual QA evidence).

## Task Authoring Notes
- Keep all tasks unchecked until implementation is completed.
- Prefer small, reviewable commits aligned to phase boundaries.
