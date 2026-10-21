# GitHub Copilot Instructions — ClinicFlow

Read the applicable `AGENTS.md` instructions, the relevant SRS and technical documents, and all five project records before planning or coding:
- `docs/PROJECT_STATE.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `docs/DECISIONS.md`
- `docs/REQUIREMENTS_TRACEABILITY.md`
- `docs/CHANGELOG.md`

Treat the SRS as the requirements source, PROJECT_STATE as a dated evidence snapshot, DECISIONS as the authority for owner-approved resolutions, IMPLEMENTATION_PLAN as ordered work rather than blanket authorization, and REQUIREMENTS_TRACEABILITY as the acceptance map. Do not choose between unresolved conflicts in DECISIONS.md independently. After any material task, update the relevant project records and append a concise CHANGELOG.md entry with the actual checks/results; never claim unrun verification. Keep documentation-only tasks read-only with respect to code and databases unless the user explicitly asks otherwise.

Before implementation, the Feature Implementer must identify applicable SRS requirements, owner-approved decisions, implementation-plan acceptance criteria, and test-case/regression IDs. Code or configuration existing is not proof of verified behavior; distinguish static inspection from an observed test/runtime result. Update directly affected documentation before completion; for explicitly read-only audits/reviews, report needed updates without editing files.

## Repository-specific context
ClinicFlow is a multi-clinic, responsive web application for a live virtual queue and clinic workflow. Intended stack: Next.js App Router + TypeScript + Supabase PostgreSQL/Auth/private Storage/Realtime + Tailwind/shadcn/ui + Vercel. Verify actual dependencies and versions in `package.json`; do not assume the stack is fully configured just because this document names it.

## Required behavior from Copilot
- Start by inspecting the current implementation. Do not replace existing architecture or rewrite whole files without need.
- For changes involving data, inspect schema/migrations, RLS policies, generated types, and all callers before editing.
- For database design, produce a proposed migration and explain its impact first. Never run it against a live project without explicit approval.
- For auth/security tasks, check server-side authorization and RLS, not only UI visibility.
- For queue logic, keep online and walk-in entries in the same session queue and allocate token/order atomically in the database.
- Never use mock data or in-memory arrays to pretend that a required production workflow is implemented.
- Keep clinical safety boundaries: no AI diagnosis, no AI prescriptions, and no autonomous SOS prioritization.
- Do not add email notifications, follow-up reminders, family profiles, fixed appointment slots, or unrelated features.
- Prefer a small, tested vertical slice over broad speculative refactoring.
- Do not claim a check passed unless it was actually run and its result observed.
- Do not commit, push, deploy, or perform destructive operations unless the user explicitly asks.

## QA workflow
Before changing application code, read `tests/README.md`, `tests/TEST_STRATEGY.md`, and the relevant test cases and regression entries. Identify affected test IDs, update coverage when behavior changes, run only available checks against safe isolated data, append actual results to `tests/TEST_EXECUTION_LOG.md`, and maintain `tests/BUG_REPORTS.md` for discovered defects. Retest linked regressions after fixes. Keep `docs/PROJECT_STATE.md`, `docs/IMPLEMENTATION_PLAN.md`, and `docs/CHANGELOG.md` current when evidence or status materially changes. Never mark an unrun or blocked check as passed. Do not install tooling, access production data, or apply migrations without the appropriate approval.

The dedicated `.github/agents/test-engineer.agent.md` profile can be selected for QA work; agent-profile files are not guaranteed to load automatically in every interaction.

Custom profiles live under `.github/agents/` and can be selected in VS Code Copilot Chat. No repository setting in this workspace automatically selects one; the profiles supplement the repository instructions and are not a substitute for them.

## Expected response for implementation tasks
Before editing: concise findings, plan, risks, and target files.
After editing: summary of actual changes, checks actually run and their results, security considerations, remaining work, and any manual steps. Mention files not inspected or behavior not verified.
