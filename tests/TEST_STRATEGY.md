# Test Strategy

## Scope and evidence

Test observable behavior against the actual repository, migrations, and an authorized isolated environment. Documentation, a rendered screen, static inspection, or creation of a test file is not evidence that a workflow passed. Do not run tests against production or use actual patient data. Resolve product conflicts through [`../docs/DECISIONS.md`](../docs/DECISIONS.md) before asserting disputed behavior.

Every execution must record environment, version/schema evidence when known, test IDs, exact commands, counts, results, evidence locations, and limitations in [`TEST_EXECUTION_LOG.md`](TEST_EXECUTION_LOG.md). Store no secrets, auth tokens, or clinical payloads in logs.

## Test levels

| Level | Verifies | Prerequisites | Evidence needed for `Passed` |
|---|---|---|---|
| Static inspection/configuration | Routes/callers, policies in tracked migrations, scripts, configuration, and consistency with requirements; identifies gaps but not runtime behavior. | Read-only source and migration access; no live credentials. | Exact files/lines or command output, scope inspected, and explicit statement that runtime behavior was not exercised. Static findings alone are not workflow passes. |
| Unit | Deterministic helpers and business rules (for example queue ordering, capacity boundaries, and EWT after D-03 is resolved). | Approved test runner, isolated fixtures, deterministic clock/input, tests independent of a database. | Exact test command and runner summary; assertions demonstrate expected boundary cases. |
| Integration | Database RPCs/constraints, RLS, Storage, Realtime, and API contracts. | Dedicated non-production Supabase project/local stack with known migration state and synthetic data; no shared or production DB. | Test output plus isolated environment and migration identity; negative authorization cases must observe denial at server/database/storage boundary. |
| End-to-end | Complete role-based journeys across UI, server, and persistence. | App and browser runner, dedicated test environment, synthetic users/fixtures, cleanup plan. | Browser/test-runner output and sanitized evidence; persisted state and failure states checked, not just visible UI. |
| Security/authorization | Patient ownership, role permissions, tenant isolation, RPC/API access, Storage and Realtime boundaries, and non-disclosure. | Isolated environment with at least two synthetic clinics and role-specific users. | Explicit allow/deny results per actor/resource pair. UI hiding alone is insufficient; do not expose record contents in evidence. |
| Regression | Previously covered requirement/defect behavior remains correct after a related change. | Linked permanent case and test method/environment available. | Case ID, prior bug/run if any, new observed result, and evidence in a new appended execution. |
| Manual acceptance | Critical journeys where automation is unavailable, including accessible, responsive, loading, validation, and failure UX. | Dedicated test account/data and human tester; no production account/data. | Tester, environment, steps, observed outcome, and sanitized screenshot/video reference if useful. Manual UI inspection cannot prove RLS or server authorization. |

## Priorities

- **P0 — Critical:** Patient safety, unauthorized clinical-data access, cross-tenant exposure, destructive data loss, or a primary workflow completely blocked.
- **P1 — High:** Core queue, authentication, registration, consultation, or other essential workflow substantially broken.
- **P2 — Medium:** Important functionality degraded with a viable workaround.
- **P3 — Low:** Minor usability, visual, or nonessential behavior issue.

Priority measures impact/urgency; it is not a test status or a substitute for defect severity. A failed test is not automatically P0. Bug reports record severity and priority separately.

## Status definitions

- `Not Run`: no execution has been performed.
- `Running`: execution is in progress; do not use as a final result.
- `Passed`: expected behavior was observed and evidence recorded.
- `Failed`: execution observed behavior that does not meet the approved expected result.
- `Blocked`: a required decision, dependency, environment, or safe fixture is unavailable; describe it.
- `Skipped`: deliberately not run with a documented reason.

Cases affected by unresolved D-07 or unavailable infrastructure remain `Blocked`. D-01–D-06 have approved behavior recorded in [`../docs/DECISIONS.md`](../docs/DECISIONS.md), but approval alone does not verify implementation. Other unexecuted cases remain `Not Run`. Never infer success from a static artifact or a previous run.

## Configured tooling and remaining gaps

`package.json` exposes `typecheck` (`tsc --noEmit`) and `test` (Node.js 24's built-in test runner with TypeScript type stripping), and includes Supabase CLI as a dev dependency. The deterministic queue-rule tests in `tests/unit/` do not need additional dependencies. Linting, integration/e2e test runners, CI, and generated Supabase types are not configured. Docker Desktop and the local Supabase stack are available; migration lint has run, but role/RLS, Storage, Realtime, and workflow integration tests remain unconfigured. Apply or reset migrations only on an explicitly approved isolated local database.

Run `corepack pnpm@12.3.4 typecheck`, `corepack pnpm@12.3.4 test`, and `corepack pnpm@12.3.4 build` when dependencies are installed. Keep integration/RLS/Storage/Realtime tests isolated and synthetic; never run migrations against an unknown/hosted project. Add browser tooling only when an isolated app/database, synthetic fixtures, and reliable cleanup are available.

## Defect handling and regression

Open a stable bug ID only for a substantiated issue. Label source-only observations `Static finding — runtime unverified`; do not invent reproduction or actual results. Keep `TEST_CASES.md`, `BUG_REPORTS.md`, and `REGRESSION_TESTS.md` linked by stable IDs. A code change is not a verified fix; rerun linked acceptance/regression checks and append the evidence.
