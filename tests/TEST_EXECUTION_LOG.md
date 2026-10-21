# Test Execution Log

Append-only history. Never replace a prior run; create a new execution ID for each rerun. Do not record secrets, tokens, credentials, or real patient data.

## RUN-20261021-012 — Apply and verify admin user-list return-type migration

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Linked Supabase project `wevutqznsvdrrnfmylrr`, matched against `.env.local` project URL and Supabase CLI linked ref. No user records were displayed.
- **Test IDs:** TC-AUTH-004 and REG-017; authenticated Super Admin listing and role transitions remain Not Run.
- **Counts:** Approved migrations applied 1; linked migration ledger match 1; anonymous RPC denial/discovery 1; authenticated RPC checks 0; returned user records displayed 0.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 exec supabase migration list --linked --output-format json` — before push, confirmed `20261021034500` was the only pending migration; after push, local and remote IDs matched for `20261021034500`.
  - `corepack pnpm@12.3.4 exec supabase db push --linked --skip-vault --yes` — exited 0 and reported only `20261021034500_fix_admin_list_users_return_types.sql` applied. `--skip-vault` avoided unrelated Vault updates.
  - Linked `supabase db query --linked` for catalog metadata did not complete: it remained at `Initialising login role...` beyond 150 seconds and was stopped; no query results were returned.
  - Anonymous `POST /rest/v1/rpc/admin_list_users` using the project's public API key and no user Authorization token — HTTP 401, SQLSTATE `42501`, `permission denied for function admin_list_users`; response contained no user data.
- **Observed result:** The approved migration was applied and recorded remotely. PostgREST recognizes the RPC and denies anonymous execution; it no longer reports the function as missing/schema-cache absent. This does not execute the function for an authorized Super Admin.
- **Overall result / limitations:** Migration deployment and anonymous denial passed. The reported result-type error is not yet confirmed fixed by an authenticated call. No Super Admin/test user credentials were available or used; no roles were changed and no user rows were returned. TC-AUTH-004 and REG-017 remain failed/pending authenticated retest; BUG-STAFF-001 is Ready for Retest.

## RUN-20261021-011 — Validate admin user-list return-type correction source

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local repository checks and local Supabase PostgreSQL; no hosted database mutation or authenticated account used.
- **Test IDs:** TC-AUTH-004 and REG-017; functional hosted Super Admin retest remains Blocked pending explicit migration approval.
- **Counts:** Typecheck passed 1; unit tests passed 5/5; production build passed 1; local database lint exited 0 with 2 existing warnings; cast-type expression query returned 5 expected types; hosted RPC executions 0.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 typecheck` — exit 0.
  - `corepack pnpm@12.3.4 test` — exit 0; 5 passed, 0 failed.
  - `corepack pnpm@12.3.4 build` — exit 0; production build completed. Next.js emitted its existing middleware-convention deprecation warning.
  - `corepack pnpm@12.3.4 exec supabase db lint --local` — exit 0; reported two `warning extra` findings for unused `v_membership` variables in existing walk-in functions.
  - `corepack pnpm@12.3.4 exec supabase db query --local --output-format json "select pg_typeof(source.user_id::uuid)::text as user_id_type, pg_typeof(source.email::text)::text as email_type, pg_typeof(source.full_name::text)::text as full_name_type, pg_typeof(source.role::text)::text as role_type, pg_typeof(source.created_at::timestamptz)::text as created_at_type from (select null::uuid as user_id, null::character varying as email, null::text as full_name, null::text as role, null::timestamptz as created_at) source;"` — returned `uuid`, `text`, `text`, `text`, `timestamp with time zone`.
- **Observed result:** Project checks passed and the explicit cast expressions yield the declared output types. This is a source/type check only; the proposed migration and actual `admin_list_users()` function were not executed.
- **Overall result / limitations:** Correction is prepared but not deployed. The reported error has not been reproduced using an authenticated hosted Super Admin. No hosted database changes were made; applying the migration to project `wevutqznsvdrrnfmylrr` requires explicit approval for that exact operation. Preserve TC-AUTH-004/REG-017 as failed pending the authenticated allow/deny and result-shape retest.

## RUN-20261021-010 — Diagnose admin user-list return type mismatch

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Repository source review and read-only local Supabase catalog query. No hosted database query or authenticated user session used.
- **Test IDs:** TC-AUTH-004, TC-STAFF-002, REG-017; hosted Super Admin call remains Not Run pending approved migration apply.
- **Counts:** User-reported SQL error reviewed 1; local type query passed 1; code/type/build checks pending final run; hosted database writes/migrations run 0.
- **Change:** Added proposed migration `20261021034500_fix_admin_list_users_return_types.sql`, which recreates `admin_list_users()` with explicit casts to its declared return column types. Updated BUG-STAFF-001 and linked test/regression records.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 exec supabase db query --local --output-format json "select ... from information_schema.columns ..."` — returned `auth.users.email` as `character varying`; `id` is UUID; profile `full_name`/`role` are text and `created_at` is timestamp with time zone.
  - Inspected migration `202610210001` and the dashboard's zero-argument RPC caller; no client signature mismatch found.
- **Observed result:** The user-reported `structure of query does not match function result type` is consistent with the uncast varchar email column being returned for a declared text column. The separate Realtime HTTP 101 Switching Protocols is normal WebSocket handshake behavior and not this SQL error.
- **Overall result / limitations:** The new migration casts all selected fields explicitly but has not been applied or executed against the hosted RPC. Runtime fix remains unverified and requires explicit approval for the exact target/project. Do not infer a successful Super Admin list load from static source inspection.

## RUN-20261021-009 — Apply role-management migrations and verify RPC discovery

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** User-approved linked Supabase project `wevutqznsvdrrnfmylrr`, which matches the project reference parsed from `.env.local`. Used the repository's linked migration push. No secret values or user records were displayed.
- **Test IDs:** TC-AUTH-004, TC-STAFF-001/002, and REG-017. Authenticated Super Admin success and non-Super-Admin authorization remain Not Run.
- **Counts:** Migrations applied 2; function catalog verification passed 1; PostgREST discovery/anonymous denial check passed 1; authenticated role workflow tests executed 0.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 exec supabase db push --linked` — exit 0; applied `202610200006_clinicflow_prescription_pdf_select.sql` then `202610210001_clinicflow_super_admin_role_management.sql`.
  - Read-only `corepack pnpm@12.3.4 exec supabase db query --linked --output-format json` querying `pg_proc`/ACL metadata — returned both `public.admin_list_users()` and `public.admin_change_user_role(uuid, text, uuid)`, both `SECURITY DEFINER`; EXECUTE grantees include `authenticated`, and do not include `anon`.
  - Read-only PostgREST POST to `/rest/v1/rpc/admin_list_users` using the public client key with no user session — returned HTTP 401 `permission denied for function admin_list_users`, confirming the RPC is discoverable and anonymous execution is denied.
  - Post-push migration-list and additional catalog SQL checks were attempted; both failed Postgres temp-role authentication (`cli_login_postgres`, SQLSTATE 28P01). The successful `db push` output lists both migrations as applied.
- **Observed result:** The schema-cache “function not found” error is resolved at the API discovery layer: PostgREST now recognizes the RPC and rejects an anonymous caller at function permissions. Migration push and catalog checks succeeded. No authenticated Super Admin call or browser dashboard flow was run.
- **Overall result / limitations:** Both approved migrations are applied to the linked target. Do not infer successful Super Admin listing or role updates from the anonymous denial test. Run TC-AUTH-004, TC-STAFF-001/002, REG-017, and the prescription Storage regression with synthetic identities and authenticated sessions. Local Supabase was not changed.

## RUN-20261021-008 — Confirm missing hosted role-management RPC

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Read-only checks against the Supabase project configured in `.env.local` and linked by the repository. The project reference matched; no URL keys or credentials were printed.
- **Test IDs:** TC-AUTH-004 and TC-STAFF-002 remain Blocked pending migration approval/application; REG-017 remains Blocked. No authenticated role operation was attempted.
- **Counts:** App/linked project-reference comparison passed 1; linked migration-history query passed 1; catalog query passed 1; database writes/migrations run 0.
- **Commands/tools used:**
  - Parsed the hostname from `NEXT_PUBLIC_SUPABASE_URL` without reading or displaying client-key values; project reference matched linked project `wevutqznsvdrrnfmylrr`.
  - `corepack pnpm@12.3.4 exec supabase migration list --linked --output-format json` — exit 0. Migrations `202610200006` and `202610210001` have empty `remote` values; prior migrations through `202610200005` have matching remote IDs.
  - `corepack pnpm@12.3.4 exec supabase db query --linked --output-format json "select ... from pg_proc ... where ... in ('admin_list_users', 'admin_change_user_role')"` — returned zero rows.
- **Observed result:** In the linked project configured for the app, neither role-management function exists in `public`, and the migration creating them is unapplied. The schema-cache error is caused by the missing function, not merely stale PostgREST cache. The earlier RUN-20261021-007 evidence incorrectly cited `--local`; this run used `--linked` and an explicit catalog query.
- **Overall result / limitations:** Root cause is confirmed. No migration or other database change was made. `supabase db push --linked` would apply both pending migrations, `202610200006` and `202610210001`, in order. This requires explicit approval for linked project `wevutqznsvdrrnfmylrr`; the migration effects include a prescription Storage SELECT policy, Super Admin-only role RPCs, clinic-membership changes/backfill, and a trigger for future clinics. Runtime allow/deny checks remain unverified.

## RUN-20261021-006 — Super Admin role management

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local Windows workspace. No Supabase database was changed or queried; no authenticated browser session was used.
- **Test IDs:** TC-AUTH-004, TC-STAFF-001, TC-STAFF-002, REG-017. Runtime role/RLS scenarios remain Not Run.
- **Counts:** Typecheck passed 1; production build passed 1; configured unit tests passed 5/5; role-assignment/RPC integration tests executed 0.
- **Change:** Added the Super Admin user-role panel and an additive, unapplied migration with guarded user-list/role-change RPCs. Clinic-role changes replace prior clinic membership with the selected clinic; Patient removes clinic memberships; Super Admin receives current and future clinic memberships. The database RPC rejects self-demotion and serializes changes to protect the last Super Admin.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 typecheck` — final run exit 0. An earlier run caught and was followed by correction of a TypeScript operator-precedence error.
  - `corepack pnpm@12.3.4 test` — exit 0; five existing queue-rule tests passed. Node emitted the existing module-type performance warning.
  - `corepack pnpm@12.3.4 build` — exit 0; production build and TypeScript validation completed. Next.js emitted the existing middleware-convention deprecation warning.
- **Observed result:** The application compiles and configured tests pass. Those unit tests do not exercise the new UI, migration SQL, RPC permissions, or database behavior.
- **Overall result / limitations:** Migration `202610210001_clinicflow_super_admin_role_management.sql` was not applied locally or remotely. No role changes, RLS allow/deny checks, clinic creation race, or browser interaction were tested. Apply only to an explicitly authorized isolated database, then run TC-AUTH-004, TC-STAFF-001/002, and REG-017 with synthetic identities.

## RUN-20261021-004 — Shared button interaction feedback

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local Windows workspace; no browser session or database used.
- **Test IDs:** TC-UX-001 / REG-016 updated; manual browser interaction remains Not Run.
- **Counts:** Typecheck passed 1; production build passed 1; unit tests passed 5/5; browser/manual interaction checks executed 0.
- **Change:** Shared buttons now have a clearer lift/shadow on hover, a press-scale response, retained focus-visible styling, and reduced-motion transition/transform suppression. Disabled controls retain their existing disabled interaction styling.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 typecheck` — exit 0.
  - `corepack pnpm@12.3.4 test` — exit 0; five existing queue-rule tests passed. Node emitted the existing module-type performance warning.
  - `corepack pnpm@12.3.4 build` — exit 0; production build and TypeScript validation completed. Next.js emitted the existing middleware-convention deprecation warning.
- **Observed result:** Static class changes compiled and all configured checks passed. The configured unit tests do not exercise button UI behavior.
- **Overall result / limitations:** No dependency was added. Hover, press, keyboard, reduced-motion, disabled and responsive behavior still require browser/manual acceptance; no runtime UI claim is made.

## RUN-20261021-003 — Prescription PDF path source correction

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local Windows workspace; source change and local checks only. No Supabase database or Storage request was made.
- **Test IDs:** TC-RX-002 source correction reviewed; authenticated Storage acceptance remains Blocked.
- **Counts:** Typecheck passed 1; production build passed 1; existing unit tests passed 5/5; authenticated Storage tests executed 0. The runTests file selector reported no discovered tests for this Node-native runner; the configured pnpm script ran the tests successfully.
- **Change:** `createPrescription()` now uses `data.patient_id` from the saved prescription RPC result to build the PDF storage folder, instead of `prescriptionForm.patientId`, which could be stale or inconsistent.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 typecheck` — exit 0.
  - `corepack pnpm@12.3.4 build` — exit 0; Next.js 16.4.0 production build/type validation completed, with the existing middleware convention deprecation warning.
  - `corepack pnpm@12.3.4 test` — exit 0; five existing queue-rule unit tests passed. Node emitted the existing module-type performance warning.
- **Observed result:** Static correction and type/build/unit checks succeeded. No component-specific test or upload was executed. User-provided policy query had `patient_folder_matches = false`; its `filename_matches = false` result remains unexplained and needs retesting against the exact saved prescription ID.
- **Overall result / limitations:** The change fixes a plausible stale-form patient-folder mismatch while preserving narrow Storage authorization. It does not prove the hosted upload now succeeds; retry the flow and continue diagnosis if RLS still rejects it.

## RUN-20261021-002 — Authorized staging policy inspection attempt

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Authorized read-only inspection attempt against the staging Supabase project reference supplied by the user; no migration or data change authorized or performed.
- **Test IDs:** TC-RX-002 remains Blocked; no Storage authorization test executed.
- **Counts:** Project-reference check passed 1; private-bucket query passed 1; migration-history query failed 1; Storage policy query failed 1; writes/migrations run 0.
- **Commands/tools used:**
  - Compared `supabase/.temp/project-ref` with the user-authorized project reference; they matched.
  - `corepack pnpm@12.3.4 exec supabase migration list --linked` — failed while connecting as `cli_login_postgres` because Postgres password authentication failed.
  - `corepack pnpm@12.3.4 exec supabase db query --linked "select policyname, cmd, roles, qual, with_check from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname in ('medical_docs_patient_upload', 'prescription_pdf_doctor_insert', 'prescription_pdf_doctor_update') order by policyname;"` — same authentication failure; no policy rows returned.
  - `corepack pnpm@12.3.4 exec supabase db query --linked "select id, public from storage.buckets where id = 'medical-documents';"` — returned `medical-documents`, `public = false`.
- **Observed result:** The linked project reference matched the authorized staging target and the bucket is private. The database login failed before the migration-history and RLS queries returned results. No migration, write, or schema change was performed.
- **Overall result / limitations:** Hosted migration state and policy definitions remain unknown. Do not request or record a password in chat; the project owner must repair/authorize local CLI database authentication or run these read-only checks through the Supabase dashboard. Once migration state is confirmed, separately authorize any deployment and retest TC-RX-002 with synthetic identities.

## RUN-20261021-001 — Prescription PDF Storage RLS diagnosis

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Read-only repository inspection and local Supabase database. No hosted project was contacted.
- **Test IDs:** TC-RX-002 investigated but not executed; authenticated Storage workflow remains Blocked.
- **Counts:** Local database catalog checks passed 2 (migration ledger and `pg_policies` query); authenticated upload/download checks executed 0; hosted queries executed 0.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 exec supabase migration list --local` — returned all 12 tracked migration IDs, including `202610200002`.
  - `corepack pnpm@12.3.4 exec supabase db query --local "select policyname, cmd, roles, qual, with_check from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname in ('medical_docs_patient_upload', 'prescription_pdf_doctor_insert', 'prescription_pdf_doctor_update') order by policyname;"` — returned the patient insert policy and the prescription doctor INSERT/UPDATE policies.
  - Inspected `components/medical-workspace.tsx`, migrations `202610180003`, `202610180004`, `202610200002`, and TC-RX-002/BUG-RX-001.
- **Observed result:** The local database contains the expected policy definitions. Migration `202610200002` restricts doctor writes to the path/name, patient, doctor membership, and finalized prescription matching the prescription row. This catalog check does not prove a matching hosted policy, that its row predicates pass for the affected prescription, or that an upload succeeds.
- **User-reported result:** Hosted browser upload returned `new row violates row-level security policy`; this was not independently reproduced.
- **Overall result / limitations:** The most likely explanation is that the hosted database has not received migration `202610200002`, but target schema/policy state is unknown. The hosted project was not queried or changed. Do not broaden RLS. Confirm the target and authorization before applying migrations; then run TC-RX-002 with synthetic records and authorized/unauthorized identities.

## RUN-20261020-013 — Demo Auth user script static validation

- **Date/time:** 2026-10-20; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local source/syntax checks only. No Supabase URL or credentials were read or used.
- **Test IDs:** TC-SEED-001 was not executed; Auth API and database tests remain `Not Run`.
- **Counts:** Passed 0; failed 0; blocked 0; skipped 0; Auth/database tests executed 0.
- **Checks:** `node --check .\supabase\demo-data\create-demo-users.mjs` passed. Six static assertions passed: ten expected accounts, Auth Admin API without direct `auth.users` writes, explicit confirmation gate, environment-only secrets, existing-account no-op, and matching account lists between the JS and SQL scripts. The first static-check attempt failed because its assertion looked for the wrong map variable name; correcting the checker to match `existingUsers.has` resulted in all six assertions passing.
- **Result / limitations:** JavaScript syntax and static safeguards only. Auth Admin API behavior, password policy acceptance, account creation, repeat execution, SQL compatibility, and application sign-in remain unverified.

## RUN-20261020-012 — Synthetic demo seed script static review

- **Date/time:** 2026-10-20; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Repository source inspection only. No Supabase project or database connection was used.
- **Test IDs:** TC-SEED-001 was not executed; database execution is `Not Run`.
- **Counts:** Passed 0; failed 0; blocked 0; skipped 0; database tests executed 0.
- **Static review:** The script references tables/columns present in the tracked identity, queue, medical workflow, and walk-in migrations. A PowerShell structural check passed eight assertions: file exists, non-production gate is opt-in, ten synthetic Auth emails are listed, membership roles match the schema constraint, four queue fixtures are specified, no destructive statements exist, all 39 test IDs are unique, and TC-SEED-001 is registered. The first checker attempt failed because it treated the case title as part of the ID; after correcting the checker to extract the ID prefix, all assertions passed. Static inspection is not a SQL parse or runtime test.
- **Commands/tools:** PowerShell static structural assertions and workspace file inspection. No SQL command was run.
- **Result / limitations:** Script authoring and source comparison only. PostgreSQL syntax, migration compatibility, repeat execution, role behavior, RLS, hosted Auth behavior, and application rendering remain unverified. Do not mark TC-SEED-001 passed until it runs in an approved isolated non-production project.

## RUN-20261020-001 — Initial QA infrastructure documentation/configuration review

- **Date/time:** 2026-10-20, 17:15:33 (+05:30; session-provided local time, exact start/end not independently timestamped)
- **Tester:** ClinicFlow Test Engineer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local repository static/documentation review; application was not started.
- **Application version:** `package.json` reports `0.1.0`; no commit/build identity available.
- **Database/migration version:** Not inspected against a database; seven migration source files were listed, but applied state is unknown.
- **Test IDs executed:** None. This entry records infrastructure/documentation inspection, not an application test run.
- **Counts:** Passed 0; failed 0; blocked 0; skipped 0; application tests executed 0.
- **Commands/tools used:** Repository file inspection via workspace tools; PowerShell commands:
  - `Get-ChildItem -Path .github\instructions, .github\agents, app, components, lib, supabase -Recurse -File | Select-Object -ExpandProperty FullName`
  - `$checks = 'pnpm','node'; foreach ($name in $checks) { $command = Get-Command $name -ErrorAction SilentlyContinue; if ($command) { Write-Output "$name available: $($command.Source)" } else { Write-Output "$name unavailable" } }; Write-Output "node_modules present: $(Test-Path node_modules)"; Write-Output "test directory present: $(Test-Path tests)"; Write-Output "github instructions directory present: $(Test-Path .github\instructions)"; git status --short`
- **QA documentation integrity check:** The first check attempt failed because its PowerShell parser did not trim the priority cell before matching; this was a checker issue, not an application/test failure. The corrected check passed: 37 case rows and unique IDs; P0 16, P1 16, P2 5; 29 `Not Run`, 8 `Blocked`; all 13 required QA files present; 0 broken relative Markdown links.
- **Final cross-document check:** Passed for 22 changed/created documentation and instruction files: no missing files, no broken relative Markdown references, 37 unique case rows, and no malformed case table rows.
- **Final cross-document check command:**
  ```powershell
  $paths = 'tests\README.md','tests\TEST_STRATEGY.md','tests\TEST_CASES.md','tests\TEST_EXECUTION_LOG.md','tests\BUG_REPORTS.md','tests\REGRESSION_TESTS.md','tests\TEST_DATA.md','tests\environment\README.md','tests\unit\README.md','tests\integration\README.md','tests\e2e\README.md','tests\security\README.md','tests\fixtures\README.md','AGENTS.md','.github\copilot-instructions.md','.github\agents\feature-implementer.agent.md','.github\agents\repo-auditor.agent.md','.github\agents\test-engineer.agent.md','docs\PROJECT_STATE.md','docs\IMPLEMENTATION_PLAN.md','docs\TESTING_AND_ACCEPTANCE.md','docs\CHANGELOG.md'
  $broken = @()
  foreach ($path in $paths) {
    if (-not (Test-Path $path)) { $broken += "Missing file: $path"; continue }
    if ($path -notmatch '\.md$') { continue }
    $file = Get-Item $path
    $content = Get-Content $file.FullName -Raw
    foreach ($m in [regex]::Matches($content, '\]\(([^)]+)\)')) {
      $target = $m.Groups[1].Value
      if ($target -match '^https?://' -or $target.StartsWith('#')) { continue }
      $relative = $target.Split('#')[0]
      if ($relative -and -not (Test-Path (Join-Path $file.DirectoryName $relative))) { $broken += "$path -> $target" }
    }
  }
  $caseRows = @(Select-String -Path tests\TEST_CASES.md -Pattern '^\| TC-')
  $ids = @($caseRows | ForEach-Object { $_.Line.Split('|')[1].Trim() })
  $badRows = @($caseRows | Where-Object { $_.Line.Split('|').Count -ne 12 })
  Write-Output "Reviewed files=$($paths.Count); missing/broken local Markdown references=$($broken.Count); case rows=$($caseRows.Count); unique IDs=$(($ids | Select-Object -Unique).Count); malformed table rows=$($badRows.Count)"
  if ($broken.Count -gt 0 -or $caseRows.Count -ne 37 -or ($ids | Select-Object -Unique).Count -ne 37 -or $badRows.Count -gt 0) { throw 'Final documentation consistency check failed.' }
  ```
- **Corrected check command:**
  ```powershell
  $rows = @(Select-String -Path tests\TEST_CASES.md -Pattern '^\| TC-')
  $ids = @($rows | ForEach-Object { $_.Line.Split('|')[1].Trim() })
  $priorities = @{}
  $statuses = @{}
  foreach ($row in $rows) {
    $cells = $row.Line.Split('|')
    $priorityCell = $cells[3].Trim()
    $priority = [regex]::Match($priorityCell, '; (P[0-3])$').Groups[1].Value
    $status = $cells[8].Trim()
    if (-not $priorities.ContainsKey($priority)) { $priorities[$priority] = 0 }
    if (-not $statuses.ContainsKey($status)) { $statuses[$status] = 0 }
    $priorities[$priority]++
    $statuses[$status]++
  }
  $expectedFiles = 'tests\README.md','tests\TEST_STRATEGY.md','tests\TEST_CASES.md','tests\TEST_EXECUTION_LOG.md','tests\BUG_REPORTS.md','tests\REGRESSION_TESTS.md','tests\TEST_DATA.md','tests\environment\README.md','tests\unit\README.md','tests\integration\README.md','tests\e2e\README.md','tests\security\README.md','tests\fixtures\README.md'
  $missingFiles = @($expectedFiles | Where-Object { -not (Test-Path $_) })
  $brokenLinks = @()
  Get-ChildItem tests -Recurse -Filter *.md | ForEach-Object {
    $file = $_
    $content = Get-Content $file.FullName -Raw
    foreach ($match in [regex]::Matches($content, '\]\(([^)]+)\)')) {
      $target = $match.Groups[1].Value
      if ($target -match '^https?://' -or $target.StartsWith('#')) { continue }
      $relative = $target.Split('#')[0]
      if ($relative -and -not (Test-Path (Join-Path $file.DirectoryName $relative))) {
        $brokenLinks += "$($file.FullName): $target"
      }
    }
  }
  Write-Output "Case rows=$($rows.Count); unique IDs=$(($ids | Select-Object -Unique).Count); priorities=$($priorities | ConvertTo-Json -Compress); statuses=$($statuses | ConvertTo-Json -Compress); missing QA files=$($missingFiles.Count); broken relative Markdown links=$($brokenLinks.Count)"
  if ($rows.Count -ne 37 -or ($ids | Select-Object -Unique).Count -ne 37 -or $missingFiles.Count -gt 0 -or $brokenLinks.Count -gt 0 -or $priorities['P0'] -ne 16 -or $priorities['P1'] -ne 16 -or $priorities['P2'] -ne 5 -or $statuses['Not Run'] -ne 29 -or $statuses['Blocked'] -ne 8) { throw 'QA documentation integrity check failed.' }
  ```
- **Observed configuration:** `package.json` has only `dev`, `build`, `start`; no test/lint/typecheck scripts or declared test framework. `pnpm` unavailable, `node` available, `node_modules` absent, no existing `tests/` or `.github/instructions/`; `git status` reports not a Git repository. `next.config.mjs` has `typescript.ignoreBuildErrors: true`.
- **Evidence:** Static inspection of root instructions, `package.json`, app/component/lib structure, Supabase migration filenames, Next/TypeScript configuration, and existing `docs/` records. No application output or runtime evidence was produced.
- **Linked bugs:** BUG-QUEUE-001, BUG-QUEUE-002, BUG-AI-001, and BUG-RX-001 were entered as static findings from the prior repository audit; none was reproduced in this review.
- **Overall result / limitations:** QA inventory and safety docs created; this is not a passing application test run. No dependencies installed; no build, typecheck, lint, unit, integration, browser, security, database, migration, Realtime, or deployment test run. Live Supabase and environment secret values were not accessed.

## RUN-20261020-002 — Source-level fix validation for bug report remediation

- **Date/time:** 2026-10-20, 17:55:00 (+05:30; session-provided local time, exact start/end not independently timestamped)
- **Tester:** ClinicFlow Test Engineer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local repository source validation only; no live Supabase project or application runtime database was started.
- **Application version:** `package.json` reports `0.1.0`.
- **Database/migration version:** Not applied or inspected against a live schema; validation is source-only.
- **Test IDs executed:** N/A for source-only validation; bug reports BUG-QUEUE-001, BUG-QUEUE-002, BUG-AI-001, and BUG-RX-001 were addressed in code and checked via compilation/build tooling.
- **Counts:** Passed 2; failed 0; blocked 0; skipped 0.
- **Commands/tools used:**
  - `powershell -NoProfile -ExecutionPolicy Bypass -Command "cd 'c:\Projects\Clinic Flow Fullstack Project\clinic-flow-fullstack-project'; npx tsc --noEmit"`
  - `powershell -NoProfile -ExecutionPolicy Bypass -Command "cd 'c:\Projects\Clinic Flow Fullstack Project\clinic-flow-fullstack-project'; npx next build"`
- **Observed result:** Both commands exited successfully. `npx tsc --noEmit` passed with no TypeScript errors. `npx next build` completed successfully and generated the app routes, including `/api/clinical-summary`, without reporting a compile failure.
- **Evidence:** The shell output from each command was captured with exit code 0.
- **Overall result / limitations:** This verifies the patched source compiles and builds cleanly, but it does not confirm live Supabase RPC semantics, auth behavior, storage permissions, or end-to-end queue workflows in a database-backed environment.

## RUN-20261020-003 — Type validation, AI route hardening, and QA register check

- **Date/time:** 2026-10-20, 17:59:34 (+05:30)
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local Windows workspace with installed `node_modules`; no application server or Supabase project was started.
- **Application version:** `package.json` reports `0.1.0`; Next.js build output reports `16.4.0`.
- **Database/migration version:** Not applied or inspected against a live database; tracked migration source only.
- **Test IDs:** TC-BUILD-001 partially exercised; TC-AI-001 implementation reviewed but API behavior not executed. TC-BUILD-001 remains Blocked because lint is not configured.
- **Counts:** Standalone typecheck passed 1; production build passed 1; failed 0; lint blocked 1; automated application tests executed 0.
- **Commands/tools used:**
  - `npm exec -- tsc --noEmit` — could not launch because PowerShell script execution policy blocks `npm.ps1`.
  - `.\node_modules\.bin\tsc.cmd --noEmit` — exit 0.
  - `.\node_modules\.bin\next.cmd build` — exit 0; TypeScript validation ran and completed.
  - PowerShell assertion over `tests/TEST_CASES.md` and Markdown links in `docs/`/`tests/`.
- **Observed result:** Next.js production build succeeded with type validation enabled; build warned that the `middleware` convention is deprecated. QA assertion reported 37 unique test cases, 9 Blocked, 28 Not Run, and 0 broken relative Markdown links. `eslint.cmd`, a lint script, and a test script are absent.
- **Source review:** The clinical-summary route now requires authenticated doctor role, doctor membership in the requested clinic, a prior consultation linking that doctor/patient/clinic, a bounded strict request, and server-retrieved bounded source records. No API, provider, role-denial, RLS, or tenant-isolation test ran.
- **Overall result / limitations:** Type/build checks pass locally, but this is not deployment readiness. D-05 AI scope/provider approval and D-06 base-schema reconciliation remain unresolved. No migrations, database operations, deployment, or browser workflow tests were performed.

## RUN-20261020-004 — Prescription PDF authorization draft and final source checks

- **Date/time:** 2026-10-20, 18:04:31 (+05:30)
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local Windows workspace with installed `node_modules`; no application server, Supabase database, or Storage service was started.
- **Application version:** `package.json` reports `0.1.0`; Next.js build output reports `16.4.0`.
- **Database/migration version:** Migration `202610200002_clinicflow_prescription_pdf_access.sql` is an un-applied draft; live schema/migration state unknown.
- **Test IDs:** TC-BUILD-001 partially exercised; TC-RX-002 blocked; no end-to-end/security test executed.
- **Counts:** Standalone typecheck passed 1; production build passed 1; failed 0; TC-BUILD-001 remains Blocked for missing lint tooling; TC-RX-002 remains Blocked for no isolated DB/Storage environment and unresolved D-06; automated application tests executed 0.
- **Commands/tools used:**
  - `.\node_modules\.bin\tsc.cmd --noEmit` — exit 0.
  - `.\node_modules\.bin\next.cmd build` — exit 0; type validation ran.
  - PowerShell assertion over 37 test cases, status counts, Markdown links in `docs/` and `tests/`, and secret-like values in `.env.example`.
- **Observed result:** Production build and standalone typecheck passed. The Next.js middleware convention deprecation warning remains. QA assertion reported 37 unique cases, 10 Blocked, 27 Not Run, 0 broken relative Markdown links, and no secret-like placeholder value.
- **Source/migration review:** The PDF UI now fails explicitly if private persistence fails, offers a retry, and refuses a browser-only fallback. The additive migration narrowly grants an assigned doctor access to a finalized prescription's exact PDF path, metadata insert, and path-attachment RPC. SQL was not executed or applied; policy behavior and retry remain unverified.
- **Overall result / limitations:** No database, RLS, Storage, consultation/prescription, API authorization, deployment, or browser workflow was verified. D-06 base-schema and D-05 AI-provider decisions remain external blockers.

## RUN-20261020-005 — Local queue rules, typecheck, package install, and build

- **Date/time:** 2026-10-20; exact start/end time not independently timestamped.
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Windows local workspace; Node.js 24.21.0; no Next.js server or Supabase services started.
- **Application version:** `package.json` reports `0.1.0`; production build reports Next.js `16.4.0`.
- **Database/migration version:** No migration was applied. The 12 tracked migration files and `supabase/config.toml` are source only; live schema is unknown.
- **Test IDs:** TC-UNIT-QUEUE-001 passed (five assertions); TC-BUILD-001 partially exercised (typecheck/build passed, lint unavailable). Integration, RLS/security, Realtime, Storage, and E2E cases were not run.
- **Counts:** Unit subtests passed 5; failed 0. Standalone typecheck passed 1; production build passed 1; frozen dependency install passed 1. TC-UNIT-QUEUE-001 is the only case marked Passed; 6 cases remain Blocked and 31 remain Not Run.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 install --frozen-lockfile` — passed after setting `allowBuilds.core-js: true`; lockfile was current.
  - `corepack pnpm@12.3.4 typecheck` — exit 0.
  - `corepack pnpm@12.3.4 test` — exit 0; 5 subtests passed.
  - `corepack pnpm@12.3.4 build` — exit 0; Next.js production build included TypeScript validation.
- **Observed result:** Tests asserted active/approved-SOS queue ordering, no SOS-priority restoration after first missed call, one-based position, clamped elapsed EWT, and first/second missed-turn helper outcomes. Build completed with the existing middleware-to-proxy deprecation warning. Node emitted a module-type performance warning for the native TypeScript test file; neither warning caused a failure.
- **Source/migration review:** Added repository identity foundation, local Supabase config, queue lifecycle schema/RPC drafts, and patient/staff UI. SQL syntax and behavior were not validated by PostgreSQL. Docker and Supabase CLI were unavailable; do not infer migration success from TypeScript/unit/build checks.
- **Overall result / limitations:** Local package/type/unit/build checks passed. No database migration, authorization denial, RLS, Storage, Realtime, browser workflow, AI provider, or deployment test ran. D-07 remains open; D-05 provider/privacy configuration and local Supabase verification remain required.

## RUN-20261020-006 — Final queue helper regression and production checks

- **Date/time:** 2026-10-20; exact start/end time not independently timestamped.
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Windows local workspace; Node.js 24.21.0; no app server or Supabase services started.
- **Application version:** `package.json` reports `0.1.0`; Next.js build reports `16.4.0`.
- **Database/migration version:** No migration was applied; local and hosted database state remains unknown.
- **Test IDs:** TC-UNIT-QUEUE-001 passed; TC-BUILD-001 partially exercised (typecheck/build passed; lint unavailable).
- **Counts:** Final unit run 5 passed, 0 failed; typecheck passed 1; production build passed 1. An initial test iteration failed one queue-order expectation; the expected order was corrected to preserve queue order for non-approved entries, then all tests passed.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 typecheck` — exit 0.
  - `corepack pnpm@12.3.4 test` — final exit 0; 5 subtests passed.
  - `corepack pnpm@12.3.4 build` — exit 0; optimized production build and TypeScript validation completed.
  - `python -c "import json, pathlib, tomllib; ..."` — package JSON and local Supabase TOML parsed successfully.
- **Observed result:** Assertions cover active/approved-SOS order, suspended priority after a missed call, position, clamped remaining wait, and missed-turn transitions. The initial comparator expectation was inconsistent with retained queue order; after correcting the test data/expectation, final test output passed. Build retains the existing middleware-to-proxy deprecation warning; Node test output retains a module-type performance warning.
- **QA consistency check:** Passed: 38 unique, well-formed test cases; 16 P0, 17 P1, 5 P2; 1 Passed, 6 Blocked, 31 Not Run; 12 ordered migration files; zero broken relative Markdown links; pnpm lock present and npm lock absent.
- **Overall result / limitations:** Source compiles and builds; pure helper tests pass. SQL migration syntax and behavior, RLS, cross-tenant denial, Storage, Realtime, browser flows, AI provider behavior, and deployment remain unverified.

## RUN-20261020-007 — Supabase/Docker CLI installation and local database retry

- **Date/time:** 2026-10-20; exact start/end time not independently timestamped.
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Windows local workspace; Node.js 24.21.0; current user is not a Windows administrator; WSL Ubuntu 24.04 available, but `sudo` requires an interactive password.
- **Application version:** `package.json` reports `0.1.0`; Supabase CLI 2.121.0; Docker CLI 29.9.1.
- **Database/migration version:** No local Supabase/PostgreSQL engine was running; no migrations were applied. No hosted project was contacted.
- **Test IDs:** TC-MIG-001 attempted and blocked; TC-BUILD-001 typecheck component passed; TC-UNIT-QUEUE-001 passed. No SQL/RLS/Storage/Realtime integration test executed.
- **Counts:** Supabase CLI install/version passed 1; Docker CLI install/version passed 1; frozen pnpm install passed 1; typecheck passed 1; unit tests passed 5/5; Docker Desktop install failed due required administrator elevation; local Supabase startup and database lint blocked.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 add -D supabase@2.121.0` — passed; CLI added as project dev dependency.
  - `winget install --id Docker.DockerCLI --exact --scope user --silent --accept-package-agreements --accept-source-agreements --source winget` — passed; winget verified the Docker download hash and installed current-user CLI.
  - `winget install --id Docker.DockerDesktop --exact --silent --accept-package-agreements --accept-source-agreements` — failed because installer requested administrator approval in a non-admin session.
  - `corepack pnpm@12.3.4 install --frozen-lockfile` — passed.
  - `corepack pnpm@12.3.4 exec supabase --version` — `2.121.0`.
  - Full-path Docker CLI `docker.exe --version` — `Docker version 29.9.1`.
  - `docker version` — client is present; Docker API at `npipe:////./pipe/docker_engine` is absent.
  - `corepack pnpm@12.3.4 exec supabase start` with Docker CLI on PATH — failed because no Docker daemon is running.
  - `corepack pnpm@12.3.4 exec supabase db lint --local` — blocked with `ECONNREFUSED 127.0.0.1:54322`.
  - `corepack pnpm@12.3.4 typecheck` — exit 0.
  - `corepack pnpm@12.3.4 test` — exit 0; 5 subtests passed.
- **Observed result:** Supabase CLI is usable from the repository; Docker CLI is installed and its user PATH entry is persisted, though the already-running VS Code process may need restart to refresh PATH. No engine or local database could be reached. The first Supabase startup attempt used a process without the newly added PATH and reported `docker: command not found`; a subsequent retry with the CLI explicitly added to PATH reached the Docker client and failed on the absent named-pipe daemon.
- **Overall result / limitations:** Installation of CLI packages and app-local checks are verified. The user must install/start Docker Desktop with administrator approval (or otherwise provide a working Linux-container engine) and reopen the shell/VS Code so PATH refreshes. Then rerun `corepack pnpm@12.3.4 exec supabase start`, `corepack pnpm@12.3.4 exec supabase db reset` only on the local stack, and database lint/migration tests. No migration or hosted database operation was performed.

## RUN-20261020-008 — Production build and database-lint retry

- **Date/time:** 2026-10-20; exact start/end time not independently timestamped.
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Windows local workspace; pnpm lockfile installation from RUN-20261020-007; Docker CLI explicitly added to the process PATH for the database check.
- **Application version:** `package.json` reports `0.1.0`; Next.js build reports `16.4.0`; Supabase CLI 2.121.0.
- **Database/migration version:** No local PostgreSQL service reachable at `127.0.0.1:54322`; no migration applied and no hosted project contacted.
- **Test IDs:** TC-BUILD-001 production-build component passed; TC-MIG-001 database-lint retry blocked. Documentation/package integrity check passed.
- **Counts:** Production build passed 1; database lint blocked 1; documentation/package integrity check passed 1.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 build` — exit 0; optimized production build, TypeScript validation, and static page generation completed.
  - `corepack pnpm@12.3.4 exec supabase db lint --local` with Docker CLI on PATH — exit 1; PostgreSQL connection refused at `127.0.0.1:54322`.
  - PowerShell/Node QA check — passed: 38 unique well-formed case rows; 16 P0, 17 P1, 5 P2; 1 Passed, 6 Blocked, 31 Not Run; 12 migrations; zero broken relative Markdown links; pnpm lock present and npm lock absent; `package.json` and Supabase TOML parse.
- **Observed result:** Application production build passes. The database lint command reaches the local database check but cannot connect because the local stack/engine is unavailable. Next.js emits an existing middleware-to-proxy deprecation warning; no build failure resulted.
- **Overall result / limitations:** App build and documentation integrity are verified. Database migration syntax, RLS, Storage, and Realtime remain unverified until an administrator installs/starts Docker Desktop or a supported Linux-container engine and Supabase starts locally. No reset, migration, or hosted database command was run.

## RUN-20261020-009 — Local Supabase startup and database lint

- **Date/time:** 2026-10-20; exact local execution time not independently timestamped.
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Windows; Docker Desktop 4.96.0 with Linux engine 29.9.1; Docker CLI 29.9.1; Node.js 24.21.0; Supabase CLI 2.121.0.
- **Application / database version:** `package.json` reports `0.1.0`; local Supabase PostgreSQL is configured at port 54322 with major version 17.
- **Test IDs:** TC-MIG-001 local stack/migration-history/lint components executed; clean reset/replay and RLS/Storage/Realtime/workflow acceptance remain blocked/not run.
- **Counts:** Docker engine check passed 1; local Supabase startup passed 1 after correcting this process's PATH; migration-history parity passed 1 (12 of 12); DB lint command exited 0 with 2 warnings; core container/port checks passed; Vector health check failed.
- **Commands/tools used:**
  - `docker version` and `docker info --format '{{.OSType}}'` — Docker Desktop engine responded and reported `linux`.
  - `corepack pnpm@12.3.4 exec supabase start` — first attempt failed because Docker config's `desktop` credential store helper was absent from PATH. Retried with `C:\Program Files\Docker\Docker\resources\bin` added to this command's process PATH; startup exited 0. No persistent PATH or Docker configuration change was made.
  - `corepack pnpm@12.3.4 exec supabase migration list --local` — all 12 local migration IDs matched the database history; an independent exact-ID check found no missing or unexpected versions.
  - `corepack pnpm@12.3.4 exec supabase db lint --local` — exit 0; two `warning extra` reports: unused `v_membership` in `public.create_walk_in` and `public.create_walk_in_with_symptoms`.
  - Docker container status and TCP checks — database, Auth, Storage, Realtime, Studio, API gateway and Inbucket services were reachable/healthy as reported; Vector was restarting/unhealthy.
  - Sanitized Vector health/log inspection — log source cannot connect to Docker Desktop endpoint `192.168.65.254:2375` (connection refused). No unauthenticated Docker TCP endpoint was enabled.
- **Observed result:** Local database connection and SQL lint now work. Migration ledger parity is observed, but this command did not independently perform a clean reset/replay. Vector log collection is unhealthy; this did not prevent local DB lint.
- **Overall result / limitations:** No application source, project configuration, migration file, local database reset, or hosted database was changed. No `db reset`, explicit migration apply, pgTAP suite, RLS allow/deny test, Storage access test, Realtime isolation test, or application workflow integration test was run. A clean migration replay needs explicit approval for the exact local reset operation; targeted authorization tests still need synthetic users and fixtures.

## RUN-20261020-010 — Environment template review and local check retry

- **Date/time:** 2026-10-20; exact local execution time not independently timestamped.
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Windows local workspace; Docker Desktop/Linux Supabase stack from RUN-20261020-009; Node.js 24.21.0; Supabase CLI 2.121.0.
- **Application/database version:** `package.json` reports `0.1.0`; local database configured on port 54322.
- **Test IDs:** TC-ENV-001 reviewed and blocked on local app configuration; TC-MIG-001 database lint rerun; TC-BUILD-001 typecheck; TC-UNIT-QUEUE-001.
- **Counts:** Environment template inspection 1 (required variable names present, local endpoint/key mismatch); `.env.local` present 0; typecheck passed 1; unit tests passed 5/5; DB lint exited 0 with two warnings.
- **Commands/tools used:**
  - PowerShell names/shape and local-value comparison of `.env.example` — required client variable names exist, but the configured API URL and both client keys do not match the running local Supabase values. Only booleans and variable names were output; values were not recorded.
  - PowerShell check of `.env.local` — file absent. The template is not loaded by Next.js automatically, so application runtime configuration was not tested.
  - `corepack pnpm@12.3.4 typecheck` — exit 0.
  - `corepack pnpm@12.3.4 test` — exit 0; all five queue-rule tests passed (Node module-type performance warning observed).
  - `corepack pnpm@12.3.4 exec supabase db lint --local` — exit 0; same two unused-`v_membership` warnings as RUN-20261020-009.
- **Observed result:** Missing values in `.env.example` were not the cause of the earlier Docker/DB connection failure: Docker and the local database are now reachable independently of the app's `.env.local`; local DB lint passes. The current template values are not for this local Supabase instance, so no application request was sent to the template endpoint. No hosted project was contacted.
- **Overall result / limitations:** No application code, `.env.example`, local credentials file, Supabase configuration, or database data was changed. No DB reset was run. To test the app locally, create `.env.local` using the current local Supabase status URL and publishable/anon client key; do not copy any hosted credentials into a local test setup. RLS, Storage, Realtime, and authenticated workflow checks remain unrun.

## RUN-20261020-011 — Local app smoke test with supplied environment file

- **Date/time:** 2026-10-20; exact local execution time not independently timestamped.
- **Tester:** ClinicFlow Feature Implementer (AI assistant)
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Windows; local Supabase stack running on loopback; Node.js 24.21.0; Next.js 16.4.0; Supabase CLI 2.121.0.
- **Test IDs:** TC-ENV-001 configuration inspection and unauthenticated page smoke test; TC-BUILD-001 typecheck; TC-UNIT-QUEUE-001.
- **Counts:** Env inspection 1 (mismatch found); local root/login HTTP checks passed 2; typecheck passed 1; unit tests passed 5/5; repeat DB lint exited 0 with 2 warnings.
- **Commands/tools used:**
  - Sanitized `.env.local` variable/endpoint comparison against local `supabase status`: the configured URL is HTTPS on port 443 and not loopback; neither configured client key equals the current local stack's publishable/anon key. Only locality, port, match booleans, key formats/lengths, and variable names were recorded; values were not printed.
  - No request was made to `.env.local`'s configured endpoint.
  - `corepack pnpm@12.3.4 exec next dev --hostname 127.0.0.1 --port 3101`, with temporary process-level local Supabase URL/publishable/anon values obtained from local stack status, overriding `.env.local` only for that dev server process — Next.js ready; local `GET /` and `GET /auth/login` each returned HTTP 200. No credentials were submitted.
  - `corepack pnpm@12.3.4 typecheck` — exit 0.
  - `corepack pnpm@12.3.4 test` — exit 0; five subtests passed.
  - `corepack pnpm@12.3.4 exec supabase db lint --local` — exit 0; same two unused-`v_membership` warnings.
  - Cleanup: stopped the temporary dev server and removed only the Next.js-generated agent-rules block it had appended to `AGENTS.md`. Confirmed port 3101 is no longer listening, the generated block is absent, and `.env.local` matches `.gitignore`.
- **Observed result:** Docker/database failure was unrelated to app environment variables: local Supabase and DB lint work. The supplied `.env.local` points to a non-local endpoint; the app was not allowed to contact it. A minimal page-render smoke test succeeds when the Next.js process is explicitly configured for the local stack. This does not verify login, auth, database-backed workflows, or RLS.
- **Overall result / limitations:** No application source, `.env.local`, project configuration, migration file, or database data was changed. No hosted project was contacted and no DB reset was run. Choose a local `.env.local` (loopback URL and local public client key) for local workflow testing, or explicitly identify/authorize a hosted target and scope before any request to it.

## RUN-20261021-005 — Prescription PDF Storage RLS SELECT gap: root-cause analysis and fix

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local Windows workspace; source/migration change and local static checks only. No Supabase database or Storage request was made.
- **Test IDs:** TC-RX-002 / REG-012 / BUG-RX-001 — static fix; authenticated Storage acceptance remains Blocked.
- **Counts:** Typecheck passed 1; production build compiled and all 9 pages generated (corepack stderr echo caused non-zero shell exit, pre-existing behavior identical to prior runs); unit tests passed 5/5; authenticated Storage tests executed 0.
- **Changes:**
  - New additive migration `supabase/migrations/202610200006_clinicflow_prescription_pdf_select.sql` adds a narrowly scoped `prescription_pdf_doctor_select` SELECT policy on `storage.objects`. This closes the RLS gap that caused Storage's upsert to fail: upsert requires SELECT + INSERT + UPDATE, but no SELECT policy covered the prescription subfolder path for the treating doctor before the first upload.
  - `components/medical-workspace.tsx` — `persistPrescriptionPdf()` now uses `upsert: false` (plain INSERT) on first upload, eliminating the SELECT dependency entirely for new objects. The `allowExisting` parameter (default `false`) allows the retry path (`retryPrescriptionPdf`, which passes `true`) to tolerate a 409-style "already exists" error and continue to upsert metadata and the prescription reference.
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 exec tsc --noEmit` — exit 0; no TypeScript errors.
  - `corepack pnpm@12.3.4 test` — exit 0; five existing queue-rule unit tests passed. Node emitted the existing module-type performance warning.
  - `corepack pnpm@12.3.4 build` (second invocation) — compiled successfully, TypeScript passed, all 9 pages generated. The corepack stderr banner (`$ next build`) causes the shell to report exit code 1; this is identical pre-existing behavior from RUN-20261021-003/004 and is not a build failure.
- **Root cause established (static analysis):** The `medical_docs_authorized_read` SELECT policy (migration `202610180003`, lines 168–185) grants doctor read access via a JOIN through `public.medical_documents`. For a first-time prescription PDF upload no `medical_documents` row exists, so the JOIN returns no rows, the SELECT policy denies the doctor, and Storage's upsert fails with HTTP 400 "new row violates row-level security policy". The INSERT and UPDATE policies were already correct.
- **Observed result:** Static analysis confirms root cause; migration and client fix are in source. No authenticated Storage retest was performed; TC-RX-002 stays Blocked until the migration is applied to staging and an authorized doctor retests first-upload and retry.
- **Overall result / limitations:** The migration must not be applied to any hosted environment without explicit owner approval of the exact SQL. After approval and application, retest: (1) first upload by the treating doctor, (2) retry after partial failure, (3) authorized patient download, (4) denial for unrelated doctor, (5) denial for unrelated patient. Update TC-RX-002 and BUG-RX-001 only after observed runtime evidence.

## RUN-20261021-007 — admin_list_users RPC root-cause diagnosis

- **Date/time:** 2026-10-21; exact start/end not independently timestamped.
- **Tester:** ClinicFlow coding assistant.
- **Branch / commit:** Not available; workspace is not a Git repository.
- **Environment:** Local Windows workspace. No database change made. No migration applied. Read-only inspection of local migration ledger, `.env.local` variable names (values redacted), dashboard caller, migration source, and QA records.
- **Test IDs:** TC-AUTH-004, TC-STAFF-001, TC-STAFF-002, REG-017 — remain Not Run / Blocked pending approved migration apply.
- **Counts:** Typecheck passed 1; unit tests passed 5/5; no database query, RPC, or browser test run.
- **Root cause (confirmed by evidence):**
  - The error `Could not find the function public.admin_list_users without parameters in the schema cache` is produced by PostgREST when the named function does not exist in the connected database.
  - `supabase migration list --local` output (JSON) shows migration `202610210001` has `"remote":""` — the remote field is empty, meaning this migration has **not been applied to the hosted Supabase project** targeted by `.env.local`.
  - Migration `202610200006` is likewise unapplied remotely (`"remote":""`). Both were added after the 12 migrations that were applied.
  - Migrations `202610170001` through `202610200005` have matching `local` and `remote` fields, confirming they are applied.
  - The function `public.admin_list_users()` is defined only in `supabase/migrations/202610210001_clinicflow_super_admin_role_management.sql` (line 5). Because the migration was not applied, the function does not exist in the hosted database. PostgREST correctly reports it is absent from the schema cache.
  - This is NOT a stale schema-cache issue. The function literally does not exist in the target database.
- **What was checked:**
  - `supabase migration list --local` — confirmed `202610210001` remote is empty.
  - `supabase/migrations/202610210001_clinicflow_super_admin_role_management.sql` — inspected full SQL; `admin_list_users()` zero-argument function is defined there with correct `SECURITY DEFINER`, `set search_path = ''`, `REVOKE … FROM public, anon`, and `GRANT EXECUTE … TO authenticated`.
  - `app/dashboard/page.tsx` line 32 — confirmed caller is `supabase.rpc('admin_list_users')` with no arguments, which matches the function signature.
  - `components/super-admin-users.tsx` line 63 — secondary caller (post-role-change refresh) is also zero-argument.
  - `.env.local` variable names — `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` are present; values not inspected. The app targets a hosted non-loopback HTTPS Supabase project.
  - No schema cache refresh was attempted (not applicable: the function itself is missing).
- **Commands/tools used:**
  - `corepack pnpm@12.3.4 exec supabase migration list --local` — exit 1 (stderr: "Connecting to local database…"), stdout JSON shows 14 migrations; `202610200006` and `202610210001` have empty `remote` fields. Exit code 1 is the CLI's existing stderr-on-connection behavior, not a failure to list.
  - `corepack pnpm@12.3.4 typecheck` — exit 0; no TypeScript errors.
  - `corepack pnpm@12.3.4 test` — exit 0; five queue-rule unit tests passed; existing module-type performance warning.
- **Required action (NOT applied here — requires explicit owner approval):**
  - Apply migration `202610210001_clinicflow_super_admin_role_management.sql` to the hosted Supabase project via `supabase db push` (or equivalent approved method), with explicit owner authorization for the exact target and SQL.
  - Optionally apply `202610200006_clinicflow_prescription_pdf_select.sql` at the same time if approved.
  - After application, verify with `supabase migration list --linked` that `202610210001` shows a non-empty `remote` timestamp. Then confirm PostgREST refreshes its schema cache (Supabase hosted projects do this automatically within ~seconds; if not, use the Supabase dashboard API Settings → Schema Cache → Reload).
  - Retest TC-AUTH-004, TC-STAFF-001, TC-STAFF-002, REG-017 with synthetic Super Admin credentials.
- **Observed result:** No application code, database, or migration was changed. The root cause is confirmed by static evidence: the migration is unapplied to the remote database.
- **Overall result / limitations:** REG-017, TC-AUTH-004, TC-STAFF-001, and TC-STAFF-002 remain **Blocked** — they cannot pass until the migration is applied to an approved isolated target and authenticated browser/integration tests are run. No false success is claimed. The fix (applying the migration) requires explicit owner authorization.
