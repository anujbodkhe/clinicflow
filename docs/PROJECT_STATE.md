# ClinicFlow Project State

**Snapshot date:** 2026-10-21  
**Evidence source:** Repository inspection, RUN-20261020-011, local policy inspection in RUN-20261021-001, failed read-only staging inspection in RUN-20261021-002, client correction with checks in RUN-20261021-003, shared-button styling checks in RUN-20261021-004, Storage RLS root-cause analysis and fix in RUN-20261021-005, Super Admin role-management source checks in RUN-20261021-006, linked project diagnosis in RUN-20261021-008, approved migration apply/function discovery in RUN-20261021-009, reported RPC error diagnosis/fix-source checks in RUN-20261021-010/011, and approved correction apply/discovery check in RUN-20261021-012; see [AUDIT_REPORT.md](AUDIT_REPORT.md) and [TEST_EXECUTION_LOG.md](../tests/TEST_EXECUTION_LOG.md).  
**Authority:** The role-management, prescription Storage, and `admin_list_users()` return-type migrations were applied to the linked app project after explicit user approval. Authenticated role behavior remains unverified.

## Executive snapshot

- **Repository:** Next.js App Router + TypeScript app with Supabase clients/auth, queue and clinical UI, 15 tracked SQL migrations, and local Supabase config. Migrations `202610200006`, `202610210001`, and `20261021034500` are applied to the linked project; the local database was not changed.
- **Verified locally:** Frozen pnpm install, configured typecheck, five Node-native queue-rule unit tests, and production build passed with TypeScript checking enabled (RUN-20261020-005/006/007/008). Supabase CLI 2.121.0 and Docker CLI 29.9.1 are installed (RUN-20261020-007).
- **Verified locally:** Docker Desktop 4.96.0/Linux engine runs the local Supabase stack; at that time, the local migration ledger matched all 12 migration IDs then tracked; `supabase db lint --local` exited successfully with two unused-variable warnings (RUN-20261020-009). The later role-management and corrective migrations are not applied locally.
- **Verified locally:** Typecheck and all five queue-rule unit tests passed. With process-only local Supabase settings, Next.js started and local `/` and `/auth/login` returned HTTP 200. The supplied `.env.local` points to a non-loopback HTTPS endpoint and its client keys do not match local Supabase; no request was sent to that endpoint (RUN-20261020-010/011).
- **Verified locally (RUN-20261021-011):** Typecheck, all five unit tests, and production build passed. Local `supabase db lint --local` exited 0 with two existing unused-variable warnings. A local PostgreSQL expression query returned the declared result types for the explicit casts in the proposed function. These checks do not execute the hosted RPC.
- **Verified locally (catalog only):** `prescription_pdf_doctor_insert` and `prescription_pdf_doctor_update` exist in local `storage.objects` policy metadata, and all 12 pre-role-management migration IDs appear in the local migration ledger (RUN-20261021-001). This does not verify upload success or hosted policy state.
- **UI source update (runtime unverified):** Shared buttons now define clearer hover and press feedback while retaining focus styles and suppressing transitions/transforms for reduced-motion preferences. Typecheck, unit tests, and production build passed (RUN-20261021-004); browser interaction was not exercised.
- **Role-management status:** The dashboard and role-management RPCs are in source. After the user's approval, migration `20261021034500` was applied to the linked project; the remote migration ledger records it, and an anonymous PostgREST call returned HTTP 401 / SQLSTATE `42501` (`permission denied for function admin_list_users`), rather than a schema-cache error (RUN-20261021-012). This confirms function discovery and anonymous denial, not authenticated Super Admin execution or the returned rows. A linked catalog query did not complete, so function metadata was not independently verified.
- **Missing-function/schema-cache issue resolved at API-discovery layer (RUN-20261021-009):** After explicit user approval, `supabase db push --linked` applied `202610200006` and `202610210001` to app project `wevutqznsvdrrnfmylrr`. Hosted catalog query found both role RPCs as `SECURITY DEFINER`, with EXECUTE granted to `authenticated`. An unauthenticated PostgREST request returned HTTP 401 `permission denied for function admin_list_users`, confirming the function was discoverable and anonymous access denied. This did not resolve the separate result-type error reported later; see RUN-20261021-012 for that correction's apply and limited verification. Authenticated dashboard and role-change behavior remain unverified.
- **Not verified:** Authenticated Storage upload/download, RLS allow/deny behavior, RPC workflow behavior, Storage/Realtime isolation, Vercel deployment, or user-level workflows. The user reported a hosted prescription upload rejection; their dashboard queries indicate the migration/policies exist and the bucket is private, while their condition query showed the folder UUID did not match the prescription patient ID. The code now uses the saved prescription's patient ID; post-fix upload is untested. The Vector log-collection container is unhealthy because its configured Docker TCP endpoint refuses connections.
- **Release status:** **Not demonstrated deployable. Do not treat as production-ready.** Critical workflow and isolated-database evidence remain missing.

## What exists in the repository

- Auth routes for email/password sign-up/sign-in, callback, sign-out, and authenticated dashboard.
- Role-aware dashboard and queue/medical workspace components.
- Supabase browser/server clients and a middleware/proxy entry point.
- Repository-owned identity/tenant foundation migration, queue/workflow/miscellaneous migrations, and `supabase/config.toml`.
- Guarded synthetic demo-data files are available in [`supabase/demo-data/`](../supabase/demo-data/): a local Auth Admin API script and repeatable SQL fixture. Both require explicit non-production confirmation; neither has been run against Supabase.
- Clinical-summary API route, PDF generation, private medical-document storage policies, deterministic queue helpers, and Node-native unit tests.

## Current workflow status

| Area | Repository status | Main limitation |
|---|---|---|
| Auth and clinic membership | Partial / authenticated retest pending | Base schema and self-signup patient trigger exist. Super Admin role-management UI/RPC and return-type correction are applied to the linked database; RPC discovery and anonymous denial are verified (RUN-20261021-009/012). The user-reported result-shape failure has not been retested as an authenticated Super Admin; role transitions and authorization remain unverified. Staff Auth account creation remains absent. |
| Patient online registration | Partially implemented | Required symptoms are enforced by UI and RPC source; persistence and the full patient journey are unverified. |
| Walk-in registration | Partial | Shared session lock/capacity and order allocation exist in migration source; live execution is unverified. |
| Shared staff queue | Partially implemented | Refresh combines online/walk-in entries and displays lifecycle controls; tenant access and Realtime have not been tested. |
| EWT/position | Partially implemented | Patient-scoped position/EWT RPC, patient display, and pure helper rules exist; helper tests pass, but SQL/UI runtime parity is unverified. |
| SOS | Partially implemented | Pending/approve/reject, reviewer/time audit, approved ordering, and urgent-only-after-approval are represented in migrations/UI; runtime remains unverified. |
| No-show | Partially implemented | Three-minute grace, first-miss pushback, second-miss standby, reactivation, and audit are represented in migrations/UI; runtime remains unverified. |
| Clinical records/documents | Partial | Some RPCs/RLS/private-bucket source exists; doctor access timing and server-side file validation need review. |
| Prescription PDF | Partially implemented / runtime unverified | Upload path uses the patient ID returned by the saved prescription (RUN-20261021-003). Root cause of Storage RLS 400 confirmed by static analysis (RUN-20261021-005): Storage `upsert: true` required SELECT + INSERT + UPDATE; no SELECT policy covered the prescription path before metadata existed. Migration `202610200006` with the narrow SELECT policy was applied to the linked project after approval (RUN-20261021-009). No authenticated upload/download test has been run. |
| Analytics/staff provisioning UI | Partial | Super Admin role assignment for existing accounts exists in source; the explicit-cast correction is applied and RPC discovery/anonymous denial were observed. The reported error has not been retested in an authenticated Super Admin session; authenticated behavior is unverified. Creating Auth accounts is not implemented. Persisted analytics remain missing. |
| AI summary | Partially implemented / blocked | API authorization/source bounds exist; provider and privacy configuration must be explicitly enabled before use. No application caller or runtime authorization was verified. |

## Database and security snapshot

- Tracked migrations now define profiles, clinics, memberships, queue, schedules, medical history/documents, consultations/prescriptions, walk-ins, queue lifecycle operations, role management, and the proposed return-type correction.
- Supabase CLI 2.121.0 and Docker Desktop's Linux engine were available locally. The local migration history still lists the 12 earlier migration IDs (RUN-20261021-001); role-management and return-type migrations were not applied locally. No `db reset` was run. Latest `supabase db lint --local` exited 0 with two `warning extra` reports for unused `v_membership` variables in walk-in functions (RUN-20261021-011).
- No generated Supabase database types were found.
- RLS, RPC and Storage policies exist in source. Local catalog inspection confirmed the prescription doctor-upload policies exist locally; their allow/deny behavior is untested. Hosted applied policies and cross-tenant behavior are unknown.
- A read-only CLI connection attempt to the authorized staging project failed Postgres authentication before migration/policy query results were returned. The user subsequently reported dashboard query results confirming the migration, policy definitions, and private bucket. No remote rows were changed. `.env.local` values were compared in process memory only; no key values were printed or recorded.
- Demo setup guide cleanup: credential-like values were removed from `supabase/demo-data/README.md` and replaced with placeholders. Rotate any service-role key or demo password that was stored there; no rotation or hosted-project request was performed here.

## Tooling and verification

- `package.json` scripts include `dev`, `build`, `start`, `typecheck`, and `test`.
- `corepack pnpm@12.3.4 install --frozen-lockfile`, `pnpm typecheck`, and `pnpm test` passed locally in RUN-20261020-005/007; `pnpm build` passed in RUN-20261020-006/008.
- The Node test runner emits a module-type performance warning; five queue-rule subtests passed.
- The local Supabase database is reachable on port 54322; API, database, Studio, Auth, Storage, Realtime, and Inbucket ports are reachable. Vector is restarting because `192.168.65.254:2375` refuses its Docker log-source connection. Do not expose unauthenticated Docker TCP to address this.
- The app reads `.env.local`, not `.env.example`. A `.env.local` file is present but its endpoint is not loopback and its client keys do not match local Supabase. No request was made to the configured endpoint. Local unauthenticated page rendering was tested with process-only local settings; auth/data workflows remain unverified.
- Workspace is not a Git repository; no Git status/diff could be inspected.
- QA registers are in [`tests/`](../tests/). Unit tests cover deterministic helpers only; they do not establish database or end-to-end behavior.

## Known documentation mismatches

- SRS §4.3 makes symptoms mandatory while §4.6 describes them as optional. User-approved D-01 requires symptoms online and allows optional walk-in symptoms.
- SRS missed-turn wording differs from the detailed user-approved D-02 policy; SRS text remains unchanged.
- SRS EWT expression differs from the clamped user-approved D-03 interpretation; see [DECISIONS.md](DECISIONS.md).
- SOS placement is clarified by user-approved D-04; SQL behavior is not yet database-verified.
- SRS sections 5–7 remain unresolved under D-07.

See [DECISIONS.md](DECISIONS.md) for approved defaults and [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for remaining work. Never turn source or unverified assumptions into runtime status claims.
