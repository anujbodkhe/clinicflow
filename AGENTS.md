# ClinicFlow Agent Instructions

## Mission
Maintain ClinicFlow, a multi-clinic virtual queue and clinic-management web application. Deliver small, tested, reviewable changes without breaking working flows or weakening data isolation.

## First action in every new task
1. Inspect the repository and relevant files before proposing edits.
2. Read the applicable `AGENTS.md` files from the workspace root down to the target directory, `.github/copilot-instructions.md`, and relevant documents in `docs/`. This applies to every agent profile; profile-specific instructions supplement, not replace, repository instructions.
3. Identify the existing implementation and whether the task is already partly implemented.
4. Check the real schema/migrations and existing generated Supabase types before designing database changes.
5. State the plan, files likely to change, risks, and verification commands. For read-only/audit requests, do not modify files.

## Project records (required)
Before planning or implementing any task, read these records as well as the relevant requirements and technical docs:
- `docs/PROJECT_STATE.md` — concise evidence-based snapshot of what exists, works, is broken, and remains.
- `docs/IMPLEMENTATION_PLAN.md` — prioritized tasks, prerequisites, acceptance criteria, and progress.
- `docs/DECISIONS.md` — approved constraints and unresolved conflicts; agents must not resolve open decisions independently.
- `docs/REQUIREMENTS_TRACEABILITY.md` — SRS requirements mapped to code, migrations, tests, and verification status.
- `docs/CHANGELOG.md` — concise record of agent changes and actual verification.

Keep these records current in the same reviewed change when implementation, requirements, decisions, task status, or verification materially changes. Before completion, update every directly affected project, QA, and feature document. Record evidence and distinguish static inspection from tested/runtime behavior. Never mark a requirement verified without observed test/runtime evidence; code or configuration existing is not proof of runtime behavior. For an explicitly read-only audit/review, do not edit files; report the documentation updates needed as follow-up instead. A documentation-only audit must not alter application/database state.

## Source of truth
- Existing code, committed migrations, generated types, and verified runtime behavior describe the current implementation.
- `docs/` describes intended behavior and contracts, but does not prove implementation.
- If code, schema, and docs disagree, report the mismatch and propose a minimal reconciliation plan. Do not silently choose one.
- Do not reintroduce superseded or competing queue schema drafts.
- Never claim something is implemented or deployable without evidence.

## Product rules
- ClinicFlow uses a live, sequential virtual queue, not fixed appointment time slots.
- Online patient registrations and receptionist-entered walk-ins must share one clinic/session queue.
- Support multiple clinics with strict tenant isolation.
- Roles: Super Admin, Clinic Admin/Receptionist, Doctor, Patient. Authorization must be enforced server-side and in database policies where applicable; hiding UI controls is not authorization.
- Patients must sign in before browsing clinic directory/queue entry. Patients can self-register.
- Show live queue position and a deterministic estimated waiting time (EWT). Do not promise exact arrival times.
- SOS requests require authorized staff review before changing queue priority. SOS is not a substitute for emergency services. AI must not decide or approve SOS priority.
- No-show behavior: when a patient's turn is called, allow a 3-minute grace period; first missed call pushes the patient back by two queue positions; second miss moves them to standby; receptionist can manually reactivate them. Preserve an auditable state transition.
- Doctors need a Today’s Queue primary workspace plus patient search and a combined consultation workspace with patient context, history/documents, and consultation/prescription form.
- Patients can view their own records; doctors can access records only for patients and clinics they are authorized to treat; reception can access queue/registration information but not full clinical records unless explicitly authorized by a verified requirement.
- Prescription PDFs are generated from clinician-reviewed data and are for patient reference. AI must not generate prescriptions.
- AI clinical summaries are a requirement only if the existing project configuration and approved scope include the AI integration. Summaries must cite/identify source records, not invent facts, distinguish historical medication mentions from confirmed current medication, and never block consultation if AI is unavailable. AI does not diagnose or determine SOS priority.
- No email notifications, follow-up reminders, family profiles, fixed appointment slots, fake backend, simulated arrays as a substitute for database functionality, or autonomous emergency triage.
- Prefer existing libraries and patterns. Do not add dependencies without explaining why.

## Engineering rules
- TypeScript strictness: avoid `any`; use generated/database types where available.
- Keep server-only secrets on the server. Never expose service-role keys, private API keys, or credentials to the browser.
- Validate all untrusted inputs on the server. Do not trust client-supplied role, clinic ID, token number, queue position, price, or authorization claims.
- Use database transactions/RPCs for concurrency-sensitive queue mutations and capacity enforcement. Do not allocate tokens with a client-side `MAX(token_number) + 1`.
- Keep tenant/ownership checks close to the data operation. Do not rely only on page middleware or UI checks.
- Use UTC timestamps in storage and convert to clinic-local time for display; verify existing conventions before changing them.
- Make state transitions explicit and auditable. Avoid deleting queue/clinical history to represent cancellation or completion.
- Do not log sensitive medical information, auth tokens, cookies, secrets, or uploaded document contents.
- Uploads must use private storage, validate size/type, and enforce authorization on upload and download.
- Use accessible labels, keyboard interaction, loading/error/empty states, and responsive layouts.
- Never create fake success states. Surface errors and preserve user input where reasonable.

## Database change rules
- Inspect the live schema and repository migrations before drafting a migration.
- Migrations must be additive and reversible where practical, use explicit constraints/indexes, and include RLS/policy implications.
- Do not reset, drop, truncate, or rewrite existing tables/data as a shortcut.
- Do not apply migrations to a connected database unless the user explicitly approves the exact operation and target environment.
- If a schema change affects generated types, update/regenerate them using the repository's existing documented method.
- Ensure queue allocation is atomic and safe under concurrent online and walk-in registration.

## Workflow
1. Understand and audit.
2. Plan one vertical slice.
3. Implement the smallest coherent change.
4. Run available lint, typecheck, tests, and build.
5. Inspect the diff for security, scope creep, broken flows, and accidental generated-file churn.
6. Report changed files, behavior, commands/results, unverified items, and any required manual action.

## QA records for application changes
- Before changing application code, read `tests/README.md`, `tests/TEST_STRATEGY.md`, and the relevant entries in `tests/TEST_CASES.md` and `tests/REGRESSION_TESTS.md`.
- Identify affected test IDs before implementation; add or update cases when observable behavior or requirements change.
- Run only checks supported by the repository and a safe, isolated environment. Do not install a test framework, connect to production, or run destructive database operations without the required approval.
- Append actual test/check results to `tests/TEST_EXECUTION_LOG.md`; create or update `tests/BUG_REPORTS.md` for defects found. Link run and bug IDs from the case and regression registers.
- Retest relevant regressions after fixes, and update `docs/PROJECT_STATE.md`, `docs/IMPLEMENTATION_PLAN.md`, and `docs/CHANGELOG.md` when evidence or task status materially changes.
- Treat `Blocked` and `Not Run` as distinct from `Passed`; report unverified behavior honestly.

The detailed QA workflow is in `tests/README.md`. The `.github/agents/test-engineer.agent.md` profile is available when explicitly selected; its presence does not guarantee automatic loading by every agent.

## Definition of done
A task is not done merely because code was written. It is done when:
- acceptance criteria are met;
- relevant tests/checks pass, or failures are clearly reported;
- authorization and tenant isolation are considered;
- errors/loading/empty states are handled;
- no unrelated feature or schema change was introduced;
- documentation/types/migrations are updated when necessary;
- the final report distinguishes verified facts from assumptions.

<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
