# ClinicFlow Change Log

Concise history of agent/user-requested repository changes and verification. Do not record secrets, credentials, or patient data. Distinguish documentation-only edits from application behavior changes.

## 2026-10-21 — Apply approved admin user-list return-type correction (RUN-20261021-012)

- **Change:** After the user's explicit approval, applied only `20261021034500_fix_admin_list_users_return_types.sql` to linked project `wevutqznsvdrrnfmylrr` using `corepack pnpm@12.3.4 exec supabase db push --linked --skip-vault --yes`. The CLI reported successful completion; Vault updates were skipped.
- **Observed verification:** `corepack pnpm@12.3.4 exec supabase migration list --linked --output-format json` showed local and remote migration ID `20261021034500`. An anonymous PostgREST call to `admin_list_users` returned HTTP 401, SQLSTATE `42501`, `permission denied for function admin_list_users`, rather than a missing-function/schema-cache error. The response did not contain user data.
- **Limitations:** A linked SQL catalog query remained at `Initialising login role...` for more than 150 seconds and was stopped without results. No authenticated Super Admin RPC call, returned-row validation, role transition, or browser test was performed; the user-reported failure is not yet confirmed fixed in an authenticated session. TC-AUTH-004 / REG-017 and BUG-STAFF-001 remain open for authenticated retest.

## 2026-10-21 — Correct admin user-list RPC return types (RUN-20261021-010/011)

- **Change:** Drafted `20261021034500_fix_admin_list_users_return_types.sql` to explicitly cast each `admin_list_users()` result field to the declared output type. The existing Super Admin authorization check and `authenticated`-only EXECUTE grant are preserved; no table/data changes are included. Updated the role-management task, traceability, project state, and QA records.
- **Diagnosis:** The user reported `structure of query does not match function result type`. Local schema inspection found `auth.users.email` is `character varying`, while the RPC declares `email text`; the mismatch is consistent with that reported error. The cause has not been independently reproduced through an authenticated hosted call.
- **Verification:** `corepack pnpm@12.3.4 typecheck` passed; `corepack pnpm@12.3.4 test` passed (5/5); `corepack pnpm@12.3.4 build` passed; `corepack pnpm@12.3.4 exec supabase db lint --local` exited 0 with two existing unused-`v_membership` warnings; a local PostgreSQL expression query returned `uuid`, `text`, `text`, `text`, and `timestamp with time zone` for the explicit cast types.
- **Limitations / required approval:** These checks do not execute `admin_list_users()` against hosted Supabase. The new migration has not been applied to local or hosted databases. Applying exactly `20261021034500_fix_admin_list_users_return_types.sql` to linked project `wevutqznsvdrrnfmylrr` requires explicit approval; after approval, run authenticated Super Admin and non-Super-Admin RPC tests with synthetic accounts. No hosted database changes were made in this run.

## 2026-10-21 — Apply approved role-management migrations

- **Change:** After the user's approval, applied `202610200006_clinicflow_prescription_pdf_select.sql` and `202610210001_clinicflow_super_admin_role_management.sql` in order to the linked app Supabase project `wevutqznsvdrrnfmylrr` using `corepack pnpm@12.3.4 exec supabase db push --linked`.
- **Observed verification:** Migration push exited 0 and reported both migration files applied. A linked catalog query returned `admin_list_users()` and `admin_change_user_role(uuid, text, uuid)` as `SECURITY DEFINER`, with EXECUTE granted to `authenticated` and not `anon`. An unauthenticated PostgREST call to `admin_list_users` returned HTTP 401 `permission denied for function admin_list_users`, confirming the RPC is discoverable and anonymous invocation is denied.
- **Limitations:** A follow-up linked migration-list/catalog query could not connect due CLI temp-role password authentication failure; no migration status was inferred from that failed query. No authenticated Super Admin dashboard call, non-Super-Admin negative RPC test, role transition, Storage upload/download, or browser interaction was run. Local Supabase was not changed. See RUN-20261021-009.

## 2026-10-21 — Confirm missing role RPC in linked Supabase project (RUN-20261021-008)

- **Change:** Recorded read-only confirmation that the app's configured project matches the linked Supabase project, migrations `202610200006` and `202610210001` are unapplied there, and the RPC catalog contains neither `admin_list_users` nor `admin_change_user_role`. Corrected the earlier RUN-20261021-007 evidence limitation (`--local` cannot establish hosted migration state) and marked role acceptance as blocked pending migration approval.
- **Scope:** QA/project documentation only. No application code or database was changed.
- **Verification:** `corepack pnpm@12.3.4 exec supabase migration list --linked --output-format json` exited 0 and showed both migrations without remote IDs. A read-only `supabase db query --linked` against `pg_proc` returned zero rows for the two RPCs. App URL project ref matched linked project `wevutqznsvdrrnfmylrr`; credentials were not displayed. See RUN-20261021-008.
- **Resolution:** The user approved applying both pending migrations. See RUN-20261021-009 for push and RPC discovery results.

## 2026-10-21 — admin_list_users RPC root-cause diagnosis (RUN-20261021-007)

- **Change:** Read-only diagnosis and QA record update only. No application code, migration, database, or schema was changed.
- **Root cause (preliminary inference, superseded by RUN-20261021-008):** The local migration list showed empty remote fields, but `--local` does not establish hosted migration status. The linked migration list and read-only hosted catalog check were not run in RUN-20261021-007; do not use that run alone as proof of hosted state.
- **Scope:** `tests/TEST_EXECUTION_LOG.md` (RUN-20261021-007 appended) and `docs/PROJECT_STATE.md` (evidence note added). No application code or database was changed.
- **Required action (NOT performed — requires explicit owner authorization):** See RUN-20261021-008, which confirmed both pending migrations against the linked app project. Apply only after explicit approval for that exact project and the effects described in RUN-20261021-008. Then verify migration status and retest with synthetic identities.
- **Verification:** `corepack pnpm@12.3.4 typecheck` exit 0; `corepack pnpm@12.3.4 test` exit 0 (5/5 unit tests passed). No database query, RPC, or browser test was run.

## 2026-10-21 — Add Super Admin user-role management

- **Change:** Added a Super Admin dashboard panel to list existing accounts and assign Patient, Clinic Admin, Doctor, Receptionist, or Super Admin roles. Added the proposed migration `202610210001_clinicflow_super_admin_role_management.sql` with Super Admin-only list/update RPCs, atomic profile/membership changes, clinic-scope replacement for clinic roles, Patient membership removal, Super Admin memberships for all current/future clinics, and serialized self/last-admin protections. Updated role-management acceptance and regression records.
- **Scope and impact:** New accounts continue to self-register as Patients. Clinic-role assignment changes that user's clinic scope to the selected clinic. Patient removes clinic memberships. Super Admin receives membership across clinics. Existing account creation through Supabase Auth is not implemented. The migration was not applied to local or hosted Supabase.
- **Security:** Role controls are enforced in `SECURITY DEFINER` database functions using `auth.uid()` and profile role checks; direct profile role updates remain unavailable to clients. User email listing is restricted by the Super Admin RPC check. Database allow/deny behavior remains unverified.
- **Verification:** `corepack pnpm@12.3.4 typecheck` passed; `corepack pnpm@12.3.4 test` passed (5/5 existing queue-rule tests); `corepack pnpm@12.3.4 build` passed. No role-management integration test or browser interaction was run; see RUN-20261021-006.

## 2026-10-21 — Fix prescription PDF Storage RLS SELECT gap (migration + client)

- **Change:** Added additive migration `supabase/migrations/202610200006_clinicflow_prescription_pdf_select.sql` with a narrowly scoped `prescription_pdf_doctor_select` SELECT policy on `storage.objects`. Changed `persistPrescriptionPdf()` in `components/medical-workspace.tsx` to use `upsert: false` (plain INSERT) on first upload, and `retryPrescriptionPdf()` to pass `allowExisting: true` to tolerate a 409 "already exists" error on retry. Updated BUG-RX-001, TC-RX-002, REG-012, TEST_EXECUTION_LOG, TEST_CASES, REGRESSION_TESTS, PROJECT_STATE, IMPLEMENTATION_PLAN.
- **Root cause (static analysis):** Storage `upsert: true` requires SELECT + INSERT + UPDATE. The existing INSERT/UPDATE policies were correct. The only SELECT policy (`medical_docs_authorized_read`) grants doctor read access via a JOIN through `public.medical_documents`; that row does not exist before first upload, so SELECT was denied and Storage rejected the INSERT with HTTP 400.
- **Security:** The new SELECT policy is restricted to: bucket `medical-documents`, exactly 2 path segments, second segment `prescriptions`, filename `<prescription-id>.pdf`, first segment = `prescriptions.patient_id`, prescription finalized + owned by `auth.uid()`, doctor clinic membership. No bucket made public; no broad SELECT added.
- **Scope:** New migration file and client component only. No existing migration, policy, table, or data altered. Migration must not be applied to any hosted environment without explicit owner approval.
- **Verification:** `corepack pnpm@12.3.4 exec tsc --noEmit` exit 0; `corepack pnpm@12.3.4 test` 5/5 pass; `corepack pnpm@12.3.4 build` compiled successfully (corepack stderr echo causes shell exit 1, pre-existing behavior). No authenticated Storage upload/download test run; see RUN-20261021-005.

## 2026-10-21 — Add clearer shared button interaction feedback

- **Change:** Updated the shared Button component with a more visible hover lift/shadow and press-scale response; reduced-motion preferences suppress transitions and transforms. Updated the UX case and regression register to cover the interaction states.
- **Scope:** Shared button styling and directly related project/QA records. No dependencies, application logic, or database state changed.
- **Verification:** `corepack pnpm@12.3.4 typecheck`, `corepack pnpm@12.3.4 test` (5 tests passed), and `corepack pnpm@12.3.4 build` passed. Build reports the existing middleware-convention deprecation warning; Node tests report the existing module-type performance warning. No browser interaction or manual accessibility test was run; see RUN-20261021-004.

## 2026-10-21 — Use persisted patient ID for prescription PDF path

- **Change:** Changed `createPrescription()` to build the PDF storage path from `data.patient_id` returned by `create_prescription`, not potentially stale `prescriptionForm.patientId`. Updated the PDF acceptance case, regression register, defect record, implementation plan, project state, and traceability.
- **Scope:** Client component and directly related QA/project records. No migration or database policy was changed.
- **Verification:** `corepack pnpm@12.3.4 typecheck`, `corepack pnpm@12.3.4 build`, and `corepack pnpm@12.3.4 test` passed; five existing unit tests passed. The production build reports the existing middleware-convention deprecation warning. No authenticated Storage upload/download test was run; see RUN-20261021-003.

## 2026-10-21 — Staging RLS inspection blocked by database authentication

- **Change:** Recorded the authorized, read-only staging inspection attempt. Confirmed the linked project reference and private bucket; migration-history and Storage policy queries could not authenticate. Updated project/QA status without treating the missing query result as proof that a migration is absent.
- **Scope:** Documentation/QA records only. No application code, migration, database row, or schema was changed.
- **Verification:** Project reference matched; `storage.buckets` reported `medical-documents` as private. `supabase migration list --linked` and the `pg_policies` query failed with Postgres password authentication before returning results. See RUN-20261021-002.

## 2026-10-21 — Prescription PDF Storage RLS failure diagnosis

- **Change:** Recorded the user-reported hosted Storage RLS failure, the local presence of migration `202610200002`'s doctor policies, and the unverified hosted migration state in project, traceability, QA, and defect records. No application code change was made because the policy already exists in source and a hosted database migration is the likely missing step.
- **Scope:** Documentation/QA records only. No application code, migration, local database data, or hosted project was changed.
- **Verification:** `supabase migration list --local` showed all 12 tracked IDs including `202610200002`; a read-only local `pg_policies` query returned the patient insert plus prescription doctor INSERT/UPDATE policies. No authenticated Storage upload/download test was run; hosted state remains unknown. See RUN-20261021-001.

## 2026-10-21 — Demo environment switching and credential cleanup

- **Change:** Replaced credential-like values in the demo setup README with placeholders. Confirmed the local app reads `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (or the anon-key fallback) from `.env.local`.
- **Scope:** Documentation only; `.env.local`, application code, Auth accounts, and databases were not changed.
- **Verification:** Confirmed the README contains the safe placeholders. No key values were retained in this record, no Supabase MCP/API was available, and no hosted project was contacted. User should rotate any service-role key or demo password previously stored in the README.

## 2026-10-20 — Guarded synthetic hosted-demo seed scripts

- **Change:** Added `supabase/demo-data/hosted-demo-seed.sql` and companion `create-demo-users.mjs` for two synthetic demo clinics and their Auth users, roles, schedules, open sessions, and online/walk-in queue. The local script uses Supabase Auth Admin API and environment variables; both workflows require explicit non-production confirmation. Updated usage instructions, QA fixture guidance, test case/regression registers, and project state.
- **Scope:** Seed artifacts and directly related documentation/QA records. No migration, Auth user, database, hosted project, or application code was changed.
- **Verification:** `node --check` and static structure checks were run without contacting Supabase. Auth creation, SQL parse/execution, RLS, idempotence, and UI behavior remain unverified. See RUN-20261020-013.

## 2026-10-20 — Local app smoke test and environment target check

- **Change:** Documented safe use of local Supabase client settings, clarified that full `supabase status` output includes secret keys, and recorded the local page smoke test.
- **Scope:** Documentation/QA only; `.env.local`, app code, Supabase config, and database contents were not changed.
- **Verification:** `.env.local` is present but targets a non-loopback HTTPS endpoint, and its client keys do not match local Supabase. No request was sent to it. A temporary Next.js dev server with process-only local settings returned HTTP 200 for `/` and `/auth/login`; typecheck and five unit tests passed; local DB lint exited 0 with two warnings. Temporary server stopped and its generated `AGENTS.md` block was removed. No hosted project or credentials were contacted; no reset was run. See RUN-20261020-011.

## 2026-10-20 — Local environment template verification

- **Change:** Clarified that Next.js reads `.env.local`, and local development must use the local Supabase URL/client key rather than values for another environment. Recorded a names-only environment check and rerun results.
- **Scope:** Documentation and QA records only; no app code, `.env.example` contents, local credentials file, Supabase configuration, or database data changed. No template endpoint or hosted project was contacted.
- **Verification:** `.env.example` contains the expected client variable names, but its values do not match the current local stack; `.env.local` is absent. Typecheck and all five unit tests passed. Local DB lint exited 0 with two unused-variable warnings. No database reset was run; see RUN-20261020-010.

## 2026-10-20 — Local Supabase startup and migration lint

- **Change:** Updated setup and QA status records with observed local Docker/Supabase results. No application source, configuration, migration files, or database data were edited.
- **Scope:** Documentation only; local Supabase containers were started for verification. No hosted project was linked or contacted.
- **Verification:** Docker Desktop Linux engine and Supabase local startup succeeded after adding Docker Desktop's credential-helper directory to the startup process PATH. Local migration history matches all 12 tracked IDs. `supabase db lint --local` exited 0 with two unused-`v_membership` warnings. Vector is unhealthy because its configured Docker log endpoint on `192.168.65.254:2375` refuses connections; unauthenticated Docker TCP was not enabled. No database reset or RLS/Storage/Realtime workflow test was run; see RUN-20261020-009.

## 2026-10-20 — Supabase and Docker CLI installation; local migration retry

- **Change:** Added Supabase CLI `2.121.0` as a pinned development dependency and installed Docker CLI `29.9.1` per-user. Updated local setup instructions and verification status.
- **Scope:** Package manifest/lockfile, current-user Docker CLI installation, and related docs. No database or hosted project was accessed.
- **Verification:** Frozen pnpm install, Supabase CLI version check, typecheck, and five unit tests passed in RUN-20261020-007. A subsequent production build and QA integrity check passed in RUN-20261020-008. Docker Desktop installer exited because administrator elevation was required and unavailable. Docker CLI runs but has no reachable daemon; `supabase start` failed on missing `npipe:////./pipe/docker_engine`, and the repeated local DB lint check could not connect to `127.0.0.1:54322`. Migrations remain unapplied and SQL runtime validation remains blocked.

## 2026-10-20 — Local foundation, queue lifecycle, and executable checks

- **Change:** Added the repository-owned identity/tenant migration and local Supabase config; added queue position/EWT, approved-SOS ordering and decisions, three-minute no-show handling, first-miss pushback, standby/reactivation, audit events, shared queue ordering, and patient/staff UI controls. Added pure queue-rule unit tests, `typecheck`/`test` scripts, and reconciled pnpm setup by approving the existing `core-js` build and removing the unused npm lockfile. Recorded user-approved D-01–D-06 and updated setup, traceability, plan, and QA docs.
- **Scope:** Repository source and unapplied migrations only. No Supabase database was started or modified; no hosted project, credentials, or deployment were accessed.
- **Verification:** `corepack pnpm@12.3.4 install --frozen-lockfile` passed in RUN-20261020-005. Final `typecheck`, `test` (five subtests passed), and production `build` passed in RUN-20261020-006. The test runner reports a module-type performance warning and Next.js reports existing middleware-convention deprecation. SQL syntax, migrations, RLS, Storage, Realtime, and end-to-end workflows remain unverified because Docker/Supabase CLI are unavailable.

## 2026-10-20 — Type-check release gate, AI source authorization, and setup accuracy

- **Change:** Removed `typescript.ignoreBuildErrors`; restricted the clinical-summary API to authenticated doctors with clinic membership and a prior consultation for the requested patient/clinic; bounded and validated request/source size; fetches summary source records server-side and returns explicit provider failures. Added Supabase-only placeholders to `.env.example` and corrected README/deployment, project-state, traceability, and QA records to reflect current evidence and unresolved blockers.
- **Scope:** Application API/configuration and directly related documentation/tests. No dependency, database schema, migration, live Supabase project, or deployment was changed.
- **Verification:** After the last source change, `.\node_modules\.bin\tsc.cmd --noEmit` and `.\node_modules\.bin\next.cmd build` passed; Next.js build performed TypeScript validation. Lint/test runners are not configured. Runtime role/RLS/provider behavior remains unverified; see RUN-20261020-003.

## 2026-10-20 — Prescription PDF authorization and persistence recovery

- **Change:** Added an additive migration draft for finalized-prescription PDF Storage/metadata authorization and guarded path attachment. Updated prescription generation to use persisted issue dates and the RPC, surfaced failures without false success, added a retry control, and removed local-only download fallback. Updated the linked defect, regression, implementation, traceability, and deployment records.
- **Scope:** Application code, an un-applied migration draft, and directly related documentation/QA records. No migration was applied and no database or production data was changed.
- **Verification:** `.\node_modules\.bin\tsc.cmd --noEmit` and `.\node_modules\.bin\next.cmd build` passed with Next.js TypeScript validation enabled. QA inventory/link/placeholder checks passed (37 unique cases, 10 blocked, 27 not run, zero broken links). SQL, RLS, Storage, and end-to-end behavior remain unverified; see RUN-20261020-004.

## 2026-10-20 — Queue registration, staff refresh, AI authorization, and prescription persistence fixes

- **Change:** Updated the patient registration client to use the symptoms-required RPC and require a symptom description; combined online plus walk-in entries in staff queue refresh; enforced role/record authorization in the clinical-summary API; persisted finalized prescription PDFs to private storage and stored their storage paths.
- **Scope:** Application code and QA defect register only. No live Supabase schema or production data was modified.
- **Verification:** `npx tsc --noEmit` and `npx next build` both exited successfully after the source-level fixes. Runtime database and storage authorization behavior remain unverified without a dedicated Supabase environment.

## 2026-10-20 — Agent instruction enforcement review

- **Change:** Clarified that every profile follows applicable `AGENTS.md` and repository Copilot instructions; made Feature Implementer prerequisites explicitly include SRS, decisions, implementation-plan acceptance criteria, and relevant test IDs. Added explicit Test Engineer register maintenance, Auditor/Security Reviewer evidence distinctions and read-only documentation exception, and profile discovery limitations.
- **Scope:** Instructions and changelog only; no application, database, or test-register behavior changed.
- **Verification:** Read the root and repository instructions, all four custom agent profiles, five project records, and QA strategy/registers. Confirmed `.github/agents/` contains four `.agent.md` profiles and no repository settings/configuration that automatically selects them. PowerShell assertions passed for all four profiles referencing `AGENTS.md` and `.github/copilot-instructions.md`, plus nine required instruction clauses. The first assertion attempt used a multiline-spanning regex for separate Test Engineer requirements and failed; the corrected individual assertions passed. No application tests/build/runtime checks were run; this instruction audit is not application verification.

## 2026-10-20 — Persistent QA registers and workflow

- **Change:** Added the `tests/` documentation structure with a test strategy, 37 requirements-driven cases, regression register, append-only execution log, defect register, synthetic-data/environment guidance, and directory-specific guidance. Logged four audit-backed static findings as runtime-unverified bug reports. Updated root and agent instructions to require case mapping, evidence logging, and defect/regression maintenance.
- **Scope:** Documentation and agent instructions only. No application code, migrations, schema, dependencies, production data, or deployment changed.
- **Verification:** Inspected `package.json`, Next.js/TypeScript configuration, app routes/components, Supabase clients, migration filenames, deployment checklist, and existing governance/audit docs. Cross-document validation passed for 22 files, with 37 unique, well-formed cases and no broken relative links. The priority/status integrity check confirmed 16 P0, 16 P1, 5 P2, 0 P3, 8 blocked, and 29 not run; its first parser attempt failed because of untrimmed priority-cell whitespace and passed after correction. Confirmed there is no existing test runner/scripts, `.github/instructions/` directory, or installed `node_modules`; `pnpm` is unavailable. No application test, build, typecheck, database, browser, or deployment verification was run. Four existing audit-backed findings were recorded as static and runtime-unverified. See `tests/TEST_EXECUTION_LOG.md`.

## 2026-10-20 — Read-only repository audit

- **Change:** Created `docs/AUDIT_REPORT.md` with SRS traceability, implementation findings, risks, and recommendations.
- **Scope:** Documentation only; no code, database, migration, deployment, or Git operation changed the project.
- **Verification:** Confirmed report file exists and contains all 12 requested report headings. Repository inspection found no installed dependencies or `pnpm`; no build, tests, or live database verification was run. `git status --short` could not run because the workspace is not a Git repository.

## 2026-10-20 — Project state and agent workflow records

- **Change:** Added `PROJECT_STATE.md`, `IMPLEMENTATION_PLAN.md`, `DECISIONS.md`, `REQUIREMENTS_TRACEABILITY.md`, and this changelog; updated `AGENTS.md` and `.github/copilot-instructions.md` to require using and maintaining these records.
- **Scope:** Documentation/instructions only. Application behavior and database state were not changed.
- **Verification:** Confirmed all five files exist, required section headings are present, project-record instructions are present in both instruction files, and new relative links resolve to repository files. No build or application tests were run; none are relevant to these documentation-only changes.
