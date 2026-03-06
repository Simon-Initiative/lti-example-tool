# Feature Architect Templates (Gleam LTI)

Use these templates as defaults unless the user specifies a different format.

## `prd.md`

```markdown
# Product Requirements Document

## 1. Feature Summary
- Name:
- Last Updated:
- Status:

Add a concise 2-4 sentence summary describing the user problem, the proposed capability, and the intended outcome.

## 2. Goals and Non-Goals
### Goals
- 

### Non-Goals
- 

## 3. Users and Primary Use Cases
- Personas:
- User stories:

## 4. Functional Requirements
1. 
2. 

## 5. Non-Functional Requirements
- Reliability:
- Performance:
- Security/Compliance:
- Observability:

## 6. Success Metrics
- Product metrics:
- Technical metrics:

## 7. Dependencies and Constraints
- Internal dependencies:
- External dependencies:
- Constraints:

## 8. Risks and Mitigations
- Risk:
- Mitigation:

## 9. Acceptance Criteria
1. Given/When/Then...
2. 
```

## `fdd.md`

```markdown
# Functional Design Document

## 1. Design Overview
- Scope covered:
- Assumptions:

## 2. System Context and Boundaries
- In-scope components:
- Out-of-scope components:

## 3. Architecture
- High-level flow:
- Module responsibilities:
- AppContext wiring impact:
- Runtime/supervision impact:

## 4. Data Design
- Schema and migration changes:
- Data lifecycle:
- Migration/backfill strategy:

## 5. Interfaces and Contracts
- Internal APIs:
- External APIs/webhooks:
- Event/message formats:

## 6. Runtime Behavior
- Request/runtime model:
- Concurrency model:
- Failure handling/retries:
- Timeouts/idempotency:

## 7. Security and Compliance
- AuthN/AuthZ impact:
- Data protection:
- Audit/logging requirements:

## 8. Observability and Operations
- Metrics:
- Logs:
- Alerts/runbooks:

## 9. Testing Strategy
- Unit:
- Integration (`wisp/simulate`, DB, LTI flows):
- Contract:
- End-to-end:

## 10. Open Questions
- 
```

## `plan.md`

```markdown
# Implementation Plan

## Phase 0 - Alignment and Readiness
### Deliverables
- Approved requirements and design baseline

### Tasks
- [ ] Confirm scope, assumptions, and dependencies
- [ ] Finalize acceptance criteria and test approach
- [ ] Identify rollout and rollback constraints

### Verification
- [ ] PRD and FDD approved
- [ ] Risks have owners and mitigations

## Phase 1 - Foundations
### Deliverables
- Core scaffolding and contracts

### Tasks
- [ ] Implement core domain modules/contexts
- [ ] Add schema changes and safe migrations
- [ ] Establish feature flags/config and baseline telemetry

### Verification
- [ ] Unit tests for core modules pass
- [ ] Migrations verified in staging-like environment

## Phase 2 - Feature Implementation
### Deliverables
- End-to-end feature behavior

### Tasks
- [ ] Implement business workflows and process interactions
- [ ] Implement external/internal interfaces
- [ ] Add error handling, retry logic, and idempotency protections

### Verification
- [ ] Integration tests pass
- [ ] Failure-path behavior verified

## Phase 3 - Hardening and Launch
### Deliverables
- Production readiness and release

### Tasks
- [ ] Add dashboards, alerts, and runbook updates
- [ ] Execute load/performance and security checks
- [ ] Run staged rollout and monitor key metrics

### Verification
- [ ] SLO/SLA criteria met
- [ ] Rollback procedure validated
- [ ] Launch sign-off recorded
```

## Task Authoring Rules

- Write each task as one actionable unit of work.
- Keep tasks independently checkable.
- Add explicit verification checkboxes per phase.
- Do not mark tasks complete unless the user provides completion status.
