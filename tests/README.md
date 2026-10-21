# ClinicFlow QA

This directory is the persistent, repository-based QA record. It contains plans and evidence registers; it does not claim that the application or database has been tested.

## Before changing application code

1. Read [`TEST_STRATEGY.md`](TEST_STRATEGY.md) and applicable entries in [`TEST_CASES.md`](TEST_CASES.md) and [`REGRESSION_TESTS.md`](REGRESSION_TESTS.md).
2. Identify affected test IDs and check unresolved product/schema decisions in [`../docs/DECISIONS.md`](../docs/DECISIONS.md).
3. Use only a dedicated isolated environment and synthetic fixtures. Follow [`TEST_DATA.md`](TEST_DATA.md) and [`environment/README.md`](environment/README.md).
4. Run only checks supported by the repository; record exact commands, results, and limitations in [`TEST_EXECUTION_LOG.md`](TEST_EXECUTION_LOG.md).
5. Record substantiated defects in [`BUG_REPORTS.md`](BUG_REPORTS.md), link them to cases, update regression coverage, and retest after fixes.
6. Keep project state, implementation plan, and changelog evidence current when status materially changes.

## Current tooling

`package.json` provides `typecheck` and `test` scripts and includes Supabase CLI as a dev dependency. Unit tests use Node.js 24's built-in test runner and native TypeScript type stripping. Deterministic queue rules are covered. Integration, RLS, Storage, Realtime, browser, and lint checks are not configured. Docker CLI is installed, but no Docker engine is running; database validation requires administrator-approved Docker Desktop startup.

The `integration/`, `e2e/`, `security/`, and `fixtures/` directories document intended scope and prerequisites; no placeholder tests are presented as passing tests.

## Status discipline

Use only `Not Run`, `Running`, `Passed`, `Failed`, `Blocked`, or `Skipped`. A pass requires an observed expected result and recorded evidence. A missing environment is `Blocked`, not `Passed`; `Skipped` needs a reason. Preserve execution history by appending new runs.

The selected `.github/agents/test-engineer.agent.md` profile supports QA work when explicitly invoked. Agent profiles are not guaranteed to load automatically; root `AGENTS.md` and `.github/copilot-instructions.md` therefore link this workflow directly.
