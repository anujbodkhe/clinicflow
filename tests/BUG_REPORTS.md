# Bug Report Register

Use stable IDs and preserve entries after closure. Separate **severity** (technical/user impact) from **priority** (urgency: P0–P3). Do not report speculation as reproduced behavior. A source-only observation must say **Static finding — runtime unverified** and link to source/audit evidence. Never include real patient data, secrets, or credentials.

## Bug report template

### BUG-<AREA>-NNN — <short title>

- **Status:** New | Triaged | In Progress | Fixed | Ready for Retest | Closed | Reopened | Won't Fix
- **Severity:** Critical | Major | Moderate | Minor
- **Priority:** P0 | P1 | P2 | P3
- **Affected feature/component:**
- **Related test ID(s) / SRS reference:**
- **Environment / version:**
- **Preconditions:**
- **Reproduction steps:** Use observed steps only; otherwise state `Not reproduced — static review only`.
- **Expected result:**
- **Actual result:** Label static findings `Static finding — runtime unverified`.
- **Reproducibility:** Reproduced count or `Not reproduced`.
- **Security / patient-safety impact:**
- **Evidence:** Sanitized file/symbol/command/output references and execution ID.
- **Root cause:** `Unknown` until established.
- **Workaround:** `None known` or verified workaround.
- **Fix reference:**
- **Retest result / closure evidence:** Do not close without verified acceptance evidence.

## Current entries

### BUG-STAFF-001 — `admin_list_users` returns an incompatible email type

- **Status:** Ready for Retest
- **Severity:** Major
- **Priority:** P1
- **Affected feature/component:** Super Admin user-role listing; `public.admin_list_users()`; migration `202610210001_clinicflow_super_admin_role_management.sql`.
- **Related test ID(s) / SRS reference:** TC-AUTH-004, TC-STAFF-002, REG-017; SRS §3 and §4.1.
- **Environment / version:** User-reported against hosted Supabase project `wevutqznsvdrrnfmylrr`; correction migration `20261021034500_fix_admin_list_users_return_types.sql` has been applied to that linked project (RUN-20261021-012).
- **Preconditions:** Role-management migrations are applied and a Super Admin dashboard calls the zero-argument `admin_list_users` RPC.
- **Reproduction steps:** User reports the dashboard/RPC returns `structure of query does not match function result type`. Realtime WebSocket HTTP 101 is normal and unrelated to this SQL error.
- **Expected result:** The authorized Super Admin receives rows matching `(uuid, text, text, text, timestamptz)` and the user list renders.
- **Actual result:** User-reported PL/pgSQL return-query type mismatch. Static source inspection finds `RETURNS TABLE email text` but selects `auth.users.email` without a cast; local schema inspection confirms `auth.users.email` is `character varying` while the other returned columns match their declared types.
- **Reproducibility:** User-reported once; not independently reproduced with an authenticated Supabase session.
- **Security / patient-safety impact:** Super Admin cannot view/assign account roles through this panel; no role authorization bypass identified.
- **Evidence:** `RUN-20261021-009` confirms the original RPC existed; local `information_schema` type query confirms the varchar/text mismatch; RUN-20261021-011 validates the cast expression types. RUN-20261021-012 records successful migration push, matching linked migration ledger, and anonymous HTTP 401 / SQLSTATE `42501` denial rather than a schema-cache error. No authenticated RPC retest has occurred.
- **Root cause:** PL/pgSQL `RETURN QUERY` requires each output column type to match the declared table result type; `auth.users.email` is varchar but the RPC declares text.
- **Workaround:** None verified. Do not remove Super Admin authorization or grant broader access to work around the error.
- **Fix reference:** Applied migration explicitly casts all selected columns to the declared output types while preserving the function's authorization check and grants.
- **Retest result / closure evidence:** Partial API discovery/anonymous denial verified in RUN-20261021-012. Authenticated synthetic Super Admin call, row-shape validation, and non-Super-Admin denial are still Not Run. Do not close until authenticated integration retest passes.

The following reports are **static findings — runtime unverified**, based on repository evidence in [`../docs/AUDIT_REPORT.md`](../docs/AUDIT_REPORT.md) and [`../docs/PROJECT_STATE.md`](../docs/PROJECT_STATE.md). No reproduction was attempted in this task.

### BUG-QUEUE-001 — Patient registration calls an RPC incompatible with the tracked symptoms migration

- **Status:** Fixed
- **Severity:** Major
- **Priority:** P1
- **Affected feature/component:** Patient queue registration; `components/queue-workspace.tsx`; migration `202610180005_clinicflow_compulsory_symptoms.sql`.
- **Related test ID(s) / SRS reference:** TC-REG-001, TC-QUEUE-001; SRS §4.3–4.6; decision D-01.
- **Environment / version:** Local repository state after fix; build verified via `npx tsc --noEmit` and `npx next build`.
- **Preconditions:** The tracked compulsory-symptoms migration is applied.
- **Reproduction steps:** Not reproduced — static review only, but the code path was updated to call the approved symptoms RPC with a required symptom string.
- **Expected result:** After D-01 resolution, patient UI and server invoke the authorized registration contract with the approved symptom behavior.
- **Actual result:** The patient queue registration form now calls `register_for_queue_with_symptoms` and requires a non-empty symptom description before submission; this aligns the client with the migration contract and prevents the incompatible call path.
- **Reproducibility:** Not reproduced; code path corrected and build-validated.
- **Security / patient-safety impact:** Prevents a blocked registration path when the required-symptoms migration is active.
- **Evidence:** [`../components/queue-workspace.tsx`](../components/queue-workspace.tsx), `RUN-20261020-002` build/typecheck output.
- **Root cause:** Client called the old RPC name without required symptoms payload.
- **Workaround:** None required in code; form now enforces symptoms.
- **Fix reference:** `register(sessionId, urgency, symptoms)` in [components/queue-workspace.tsx](../components/queue-workspace.tsx).
- **Retest result / closure evidence:** TypeScript compile passed (`npx tsc --noEmit` exit 0) and production build passed (`npx next build` exit 0). Runtime DB behavior remains unverified against a live Supabase project.

### BUG-QUEUE-002 — Staff queue refresh omits online entries

- **Status:** Fixed
- **Severity:** Major
- **Priority:** P1
- **Affected feature/component:** Staff queue refresh; `components/queue-workspace.tsx`, `refreshStaff()`.
- **Related test ID(s) / SRS reference:** TC-QUEUE-002; SRS §4.2–4.3.
- **Environment / version:** Local repository state after fix; build verified via `npx tsc --noEmit` and `npx next build`.
- **Preconditions:** A session contains online and walk-in entries; staff queue refresh is invoked.
- **Reproduction steps:** Not reproduced — static review only, but the refresh code now merges online and walk-in entries into one combined staff queue.
- **Expected result:** Refreshed staff view includes online and walk-in entries in one authorized session queue.
- **Actual result:** `refreshStaff()` now loads queue sessions and then merges `queue_entries` for online patients with `list_clinic_walk_ins()` walk-ins before sorting the combined list.
- **Reproducibility:** Not reproduced; logic corrected and compiled successfully.
- **Security / patient-safety impact:** Staff now operate on the complete authorized queue without missing online registrations.
- **Evidence:** [`../components/queue-workspace.tsx`](../components/queue-workspace.tsx), `RUN-20261020-002` build/typecheck output.
- **Root cause:** Refresh path only loaded walk-in RPC results.
- **Workaround:** None required.
- **Fix reference:** `refreshStaff()` in [components/queue-workspace.tsx](../components/queue-workspace.tsx).
- **Retest result / closure evidence:** TypeScript compile passed (`npx tsc --noEmit` exit 0) and production build passed (`npx next build` exit 0). Live Supabase queue behavior remains unverified without a database environment.

### BUG-AI-001 — Clinical summary endpoint accepted caller-supplied records without required scope

- **Status:** Ready for Retest
- **Severity:** Critical
- **Priority:** P0
- **Affected feature/component:** `app/api/clinical-summary/route.ts`.
- **Related test ID(s) / SRS reference:** TC-AI-001; SRS §2, §3, §8; decision D-05.
- **Environment / version:** Local repository; `next` 16.4.0. No database or provider runtime was available.
- **Preconditions:** Authenticated caller submits missing/optional identifiers or caller-controlled `history`.
- **Reproduction steps:** Not reproduced — static review found the endpoint accepted caller-provided history and could return before authorization when identifiers/history were absent.
- **Expected result:** Require an authenticated doctor, valid patient and clinic identifiers, clinic doctor membership, and an authorized patient relationship; retrieve bounded source records server-side only.
- **Actual result:** `POST` now rejects bodies over 2 KB, validates a strict patient/clinic UUID schema, requires doctor role plus clinic membership and a prior doctor-patient consultation in that clinic, and retrieves source histories/consultations from Supabase rather than accepting clinical text from the caller. Provider output remains advisory and provider errors return an explicit 502.
- **Reproducibility:** Not reproduced; the fix has source review and TypeScript/build validation only.
- **Security / patient-safety impact:** Prevents unrestricted clinical text summarization by unauthorized users and blocks disallowed patient/clinic access.
- **Evidence:** [`../app/api/clinical-summary/route.ts`](../app/api/clinical-summary/route.ts), RUN-20261020-003.
- **Root cause:** Optional identity scope and client-controlled clinical history were used before reliable authorization.
- **Workaround:** AI scope/provider approval remains unresolved under D-05; no app caller was found.
- **Fix reference:** `POST` handler in [app/api/clinical-summary/route.ts](../app/api/clinical-summary/route.ts).
- **Retest result / closure evidence:** `tsc --noEmit` and `next build` passed in RUN-20261020-003. API role/tenant denial tests remain blocked by D-05 and the absence of an isolated Supabase environment; do not close until those checks pass.

### BUG-RX-001 — Prescription PDF persistence is blocked by RLS and can show false success

- **Status:** Ready for Retest
- **Severity:** Moderate
- **Priority:** P1
- **Affected feature/component:** Browser-generated prescription PDF in `components/medical-workspace.tsx`.
- **Related test ID(s) / SRS reference:** TC-RX-002; SRS §4.7, §8.
- **Environment / version:** User-reported staging Supabase Storage request; user reports migration and policy rows are present and bucket is private. Local repository uses `next` 16.4.0; local Supabase catalog is inspectable.
- **Preconditions:** A doctor finalizes a synthetic prescription and attempts to upload the PDF.
- **Reproduction steps:** User reports finalizing a prescription followed by a Storage upload response `new row violates row-level security policy`. Not independently reproduced. Read-only local inspection shows migration `202610200002`'s doctor insert/update policies exist in the local database. The authorized remote query attempt failed before returning migration/policy rows; no authenticated local upload was performed.
- **Expected result:** A deterministic PDF from persisted, doctor-reviewed data is stored privately and downloadable only by authorized users; storage failure is explicit, and a missing stored artifact cannot be presented as a successful download.
- **Actual result:** The browser reports the hosted upload is denied by Storage RLS. The user checked the dashboard and reports the migration and doctor policies exist and the bucket is private. Their query output showed finalized status and doctor membership true, but the patient-folder comparison false; the filename comparison was also reported false, though that result is inconsistent if the query filter ID and filename ID are identical. Static inspection found the client preferred `prescriptionForm.patientId` over the patient ID returned by the saved prescription. The upload now uses `data.patient_id`; storage behavior remains unverified.
- **Reproducibility:** User-reported on the hosted project; not independently reproduced. Local policy catalog inspection only; no authenticated upload/download test.
- **Security / patient-safety impact:** Keeps the prescription artifact in the patient’s private vault and ensures the patient/doctor must access it via authorized bucket and row references instead of only a browser download.
- **Evidence:** [`../components/medical-workspace.tsx`](../components/medical-workspace.tsx), [`../supabase/migrations/202610200002_clinicflow_prescription_pdf_access.sql`](../supabase/migrations/202610200002_clinicflow_prescription_pdf_access.sql), RUN-20261020-003, RUN-20261021-001/002.
- **Root cause:** The PDF upload path was built using potentially stale form state (`prescriptionForm.patientId`) instead of the patient ID returned by the newly saved prescription. This can make the patient folder in the object path differ from `prescriptions.patient_id`, which causes the exact-path Storage policy to reject the insert. The code now uses `data.patient_id`. The user's reported filename mismatch is not explained by this change and needs retesting with the same prescription UUID used for the upload.
- **Workaround:** No verified workaround. After deploying the updated client, retry with a doctor assigned to the finalized prescription; do not broaden the bucket policy or use a service-role key in the browser.
- **Fix reference:** `persistPrescriptionPdf()`, `retryPrescriptionPdf()`, and `downloadPrescription()` in [components/medical-workspace.tsx](../components/medical-workspace.tsx); additive migration [`202610200002_clinicflow_prescription_pdf_access.sql`](../supabase/migrations/202610200002_clinicflow_prescription_pdf_access.sql).
- **Retest result / closure evidence:** The component now uses the saved prescription's patient ID for the PDF object path. Typecheck, production build, and five existing unit tests pass in RUN-20261021-003. No component-specific or authenticated Storage test ran; retry the same workflow and confirm the resulting path/authorization before closing. TC-RX-002 stays Blocked.

### BUG-QUEUE-003 — Queue lifecycle, SOS decisions, and patient position lacked complete server-side operations

- **Status:** Ready for Retest
- **Severity:** Major
- **Priority:** P1
- **Affected feature/component:** Queue SQL lifecycle, SOS moderation, position/EWT, and staff/patient queue views.
- **Related test ID(s) / SRS reference:** TC-QUEUE-006, TC-QUEUE-007, TC-SOS-001, TC-SOS-002, TC-NOSHOW-001; SRS §4.3–4.5; D-02–D-04.
- **Environment / version:** Local source review; no PostgreSQL or Supabase services available.
- **Preconditions:** Tracked queue foundation and SOS migrations; database behavior has not been exercised.
- **Reproduction steps:** Not reproduced — static review found that no-show handling, SOS rejection/audit, owner-approved ordering, patient position, and secure server-computed EWT were absent or incomplete in prior migration source.
- **Expected result:** Authorized, auditable database transitions implement the approved SOS/no-show policy; patient-only position/EWT calculation uses the approved formula; normal urgency cannot be self-assigned.
- **Actual result:** Additive migration drafts and UI now define these operations; pure helper rules have five passing unit assertions. SQL and UI/database behavior remain runtime-unverified.
- **Reproducibility:** Not reproduced; static source review only.
- **Security / patient-safety impact:** Incorrect ordering, unreviewed urgency, or unaudited queue state could affect patient wait order and staff decisions.
- **Evidence:** [`../supabase/migrations/202610200003_clinicflow_queue_standby_status.sql`](../supabase/migrations/202610200003_clinicflow_queue_standby_status.sql), [`../supabase/migrations/202610200004_clinicflow_queue_lifecycle_schema.sql`](../supabase/migrations/202610200004_clinicflow_queue_lifecycle_schema.sql), [`../supabase/migrations/202610200005_clinicflow_queue_lifecycle_operations.sql`](../supabase/migrations/202610200005_clinicflow_queue_lifecycle_operations.sql), [`../lib/queue-rules.ts`](../lib/queue-rules.ts), RUN-20261020-005.
- **Root cause:** The prior SQL/API surface had no complete persisted state machine for the approved queue rules.
- **Workaround:** None verified. Do not treat source migrations as deployed behavior.
- **Fix reference:** Queue lifecycle migrations and `QueueWorkspace`.
- **Retest result / closure evidence:** Typecheck, build, and helper tests pass, but the migration is unapplied; run local Supabase migration, role/RLS, grace-boundary, queue-order, and EWT integration tests before closure.

---

## BUG-RX-001 update — RUN-20261021-005 root-cause finding

**Supersedes the Ready for Retest entry above.** The root cause is now confirmed by static analysis (RUN-20261021-005):

- **Status updated to:** Ready for Retest (root cause confirmed; migration and client fix in source; runtime retest pending)
- **Severity upgraded to:** Critical — upload fails for every finalized prescription PDF on both first upload and retry
- **Root cause (confirmed):** Storage `upsert: true` requires SELECT + INSERT + UPDATE. The INSERT and UPDATE policies (`prescription_pdf_doctor_insert`, `prescription_pdf_doctor_update` from migration `202610200002`) are correctly predicated. The **only** SELECT policy on `storage.objects` for `medical-documents` is `medical_docs_authorized_read` (migration `202610180003` lines 168–185), which grants doctor read access via a JOIN through `public.medical_documents`. For a first-time upload no `medical_documents` row exists yet; the JOIN returns nothing; SELECT is denied; Storage rejects the INSERT with HTTP 400 "new row violates row-level security policy". The stale-form patient-ID fix (RUN-20261021-003) was a contributing factor but insufficient on its own; the SELECT gap persists independently.
- **Fix (pending owner approval to apply to staging):**
  1. New additive migration [`supabase/migrations/202610200006_clinicflow_prescription_pdf_select.sql`](../supabase/migrations/202610200006_clinicflow_prescription_pdf_select.sql) — adds `prescription_pdf_doctor_select` SELECT policy on `storage.objects`. Predicate is identical to the existing INSERT/UPDATE policies (finalized prescription + doctor membership + exact path). No dependency on `medical_documents`.
  2. [`components/medical-workspace.tsx`](../components/medical-workspace.tsx) `persistPrescriptionPdf()` — `upsert: false` on first upload eliminates SELECT dependency for new objects; `retryPrescriptionPdf()` passes `allowExisting: true` to tolerate a 409 "already exists" error and continue metadata/reference recording.
- **Checks passed (RUN-20261021-005):** TypeScript exit 0; 5/5 unit tests pass; production build compiled successfully (corepack stderr banner causes shell exit 1, pre-existing behavior).
- **Retest required before closure:** Apply migration to staging with explicit owner approval; then confirm: (1) first upload, (2) retry after partial failure, (3) authorized patient download, (4) unrelated doctor denied, (5) unrelated patient denied.
