# ClinicFlow Repository Audit

**Audit type:** Read-only repository audit  
**Audit date:** 2026-10-20  
**Repository root:** `C:\Projects\Clinic Flow Fullstack Project\clinic-flow-fullstack-project`  
**SRS:** [`docs/srs.md`](srs.md)

> No application files or database resources were modified during the audit. The audit is based on the repository contents only; live Supabase state and runtime behavior were not verified.

## 1. Executive status

The repository contains a real Next.js application with Supabase Auth calls, a role-aware dashboard, queue and clinical UI, seven SQL migrations, and an AI-summary route. These artifacts are not proof that the end-to-end workflows work: no tests, build, or live database verification were available.

**Deployability is not established.** From the repository alone, the migration chain lacks the `profiles`, `clinics`, and `clinic_memberships` table definitions that later migrations depend on. Also, if the compulsory-symptoms migration has been applied, the patient UI calls a queue-registration function that migration revokes for authenticated users. The repository is not shown to be production-ready or clinically safe.

All listed instruction and requirements documents were present. The SRS is [`docs/srs.md`](srs.md). No additional requirements documents were found in `docs/`.

## 2. SRS summary

The SRS describes a multi-clinic platform with a **live sequential queue**, not fixed-time appointment slots. It calls for patient self-registration, authenticated clinic discovery, staff provisioning, doctor schedules and session capacity, a shared online/walk-in queue, atomic token allocation, live queue updates and an EWT estimate, moderated SOS, patient history and private uploads, clinician-authored consultations and prescription PDFs, and persisted-record analytics.

It also requires server/database/storage authorization, private clinical files, real persisted data, and appropriate pre-clinical-use review. AI summaries are described as advisory, source-grounded, and non-blocking when unavailable; the chosen stack says they use an actually configured AI provider. The document's numbered sections jump from 4.8 to 8, so sections 5–7 are not present in the SRS file.

The SRS does not assign unique requirement IDs beyond its section numbering. The matrix below uses those section references without creating new requirement IDs.

## 3. SRS traceability matrix

“Partially implemented” means code or migration artifacts exist, but end-to-end behavior is incomplete or unverified. **No end-to-end feature is marked Verified** because no runtime or automated checks could be run.

| SRS reference and requirement | Type | Feature/component | Status | Evidence, gap, and recommended next action |
|---|---|---|---|---|
| §3: Super Admin, Clinic Admin, Doctor, Receptionist, Patient roles; enforce authorization server-side and at database/storage layers | Security / functional | Auth, membership, RLS, role workspaces | **Partially implemented** | Membership checks and RLS policies appear in [`supabase/migrations/202610180001_clinicflow_queue_foundation.sql`](../supabase/migrations/202610180001_clinicflow_queue_foundation.sql) and [`supabase/migrations/202610180003_clinicflow_medical_workflows.sql`](../supabase/migrations/202610180003_clinicflow_medical_workflows.sql). The repository does not define the underlying profile, clinic, or membership tables; staff provisioning was not found in inspected routes/UI. Verify the full schema and role lifecycle in an isolated environment. |
| §4.1: Patient self-registration and sign-in; staff accounts provisioned by authorized admins; sign-in before browsing clinics; searchable directory and direct clinic links | Functional / security / usability | `/auth/*`, dashboard and availability | **Partially implemented** | Email/password UI exists in [`app/auth/sign-up/page.tsx`](../app/auth/sign-up/page.tsx) and [`app/auth/login/page.tsx`](../app/auth/login/page.tsx); dashboard checks the session in [`app/dashboard/page.tsx`](../app/dashboard/page.tsx). Patients can see available sessions there, but no searchable clinic directory, direct clinic-link flow, or staff-provisioning workflow was found. |
| §4.1–4.2: Multiple clinics; doctors configure schedules; admins configure limits; reserve approximately 40–50% for walk-ins; show remaining online places; close registration/session | Functional | Schedule/session UI, database | **Partially implemented** | Schedule/session tables and admin RPCs exist in the queue foundation migration; the dashboard displays session counts in [`components/queue-workspace.tsx`](../components/queue-workspace.tsx). Schedule create/update RPCs require Clinic Admin/Super Admin rather than the doctor managing their own schedule. No percentage constraint or verified display of remaining *online* capacity was found; external database state is unknown. |
| §4.3: Patient journey includes a **mandatory symptom form**; online and walk-ins share a queue; token allocation and capacity are atomic | Functional / security | Registration RPCs and staff queue | **Blocked for patient registration; partially implemented for allocation/walk-ins** | SQL allocation functions lock the session row, check capacity, allocate `max(token)+1`, and have a unique session/token constraint. But the patient handler calls `register_for_queue` in [`components/queue-workspace.tsx`](../components/queue-workspace.tsx); [`supabase/migrations/202610180005_clinicflow_compulsory_symptoms.sql`](../supabase/migrations/202610180005_clinicflow_compulsory_symptoms.sql) revokes that function from authenticated users and grants the new symptoms-required RPC instead. The UI does not submit symptoms to that new RPC. Confirm migration state, then reconcile caller and contract. |
| §4.4: EWT formula, 10-minute standard / 15-minute urgent estimates, recalculation, live position, and estimate disclaimer | Functional / usability | Patient queue status and Realtime | **Partially implemented** | Realtime subscriptions exist in `queue-workspace.tsx`. Patient display explicitly says “position unavailable” and shows the row's fixed `estimated_minutes`, not the SRS queue-based EWT formula. Implement and test deterministic position/EWT calculations and verify authorized, scoped updates. |
| §4.5: SOS request remains pending until authorized review; approval inserts directly behind active consultation; rejection leaves normal order; emergency-services notice | Functional / safety | SOS RPCs and queue UI | **Partially implemented** | Request and approval RPCs exist; staff UI exposes approval in `queue-workspace.tsx`. No rejection operation, decision actor/outcome audit, or clear emergency-services notice was found. Queue ordering prioritizes all urgent entries rather than placing an approved request directly behind the active consultation. Registration RPCs also accept `urgent`, so database authorization does not enforce staff approval as the only route to urgent priority. |
| §4.6: Distinguish patient-reported information, uploaded originals, and clinician records; validate PDF/images and size | Security / functional | Medical workspace, Storage | **Partially implemented** | Patient history, private `medical-documents` bucket, metadata, and Storage policies exist in migrations 003/004. Type/size validation is in the browser in [`components/medical-workspace.tsx`](../components/medical-workspace.tsx), not shown as server-side content validation. Upload paths reuse the sanitized filename and use `upsert`, so an upload can overwrite an existing original. Doctor document access is tied to an existing consultation, which can prevent access before consultation starts. |
| §4.7: Doctor records consultation and structured medication; deterministic doctor-reviewed PDF is stored privately in patient vault | Functional / security | Medical workspace, consultation/prescription RPCs | **Partially implemented** | Consultation and prescription data functions exist in migration 003. PDF creation is a browser-side `jsPDF` download in `medical-workspace.tsx`; it is not stored in the private vault, and no private prescription PDF download path was found. Walk-in consultations are added in migration 007, but prescription schema still requires `patient_id`, which is null for a walk-in consultation; the prescription insert consequently cannot represent that case. |
| §4.8: Analytics from persisted records, including daily volume, peak hours, duration, categories, completion statistics | Functional | Analytics UI/data | **Missing** | No analytics route, query, or UI was found. The landing page includes fixed clinic/queue figures in [`app/page.tsx`](../app/page.tsx); these are not persisted analytics and should not be presented as genuine operational data. |
| §8: Keep secrets server-side; private storage; atomic queue operations; real persisted records; AI advisory/non-blocking; excluded features remain excluded | Security / functional / deployment | Supabase clients, migrations, API route | **Partially implemented / Not verifiable** | Browser/server clients use public URL and publishable/anon keys in `lib/supabase/client.ts` and `server.ts`. No service-role key was found in inspected source. No `.env.example` or deployment environment was available to verify configuration. An AI route exists, but its authorization and integration gaps are detailed in §7. |
| §9: Demo checklist—provision roles, register both entry types, shared capacity, live updates, SOS/no-show, records/PDF, analytics, cross-tenant denial | Functional / security / acceptance | End-to-end workflows and tests | **Not verifiable** | No test or browser-acceptance suite is present. Several checklist elements are missing or blocked above. Database and cross-tenant behavior were not exercised. |

## 4. Repository and technology map

**Actual stack:** Next.js 16.4.0 App Router, React 19.2.4, TypeScript 5.7.3, Supabase JS/SSR, Tailwind CSS 4, lucide-react, Zod, AI SDK, and jsPDF. These versions and packages are listed in [`package.json`](../package.json). The installed dependency tree was absent, so runtime compatibility was not checked.

**Routes found:**
- `/` in [`app/page.tsx`](../app/page.tsx)
- `/dashboard` in [`app/dashboard/page.tsx`](../app/dashboard/page.tsx)
- `/auth/login`, `/auth/sign-up`, `/auth/callback`, `/auth/sign-out`
- `/api/clinical-summary` in [`app/api/clinical-summary/route.ts`](../app/api/clinical-summary/route.ts)

The main workflow UI is in [`components/queue-workspace.tsx`](../components/queue-workspace.tsx) and [`components/medical-workspace.tsx`](../components/medical-workspace.tsx). Supabase clients are in [`lib/supabase/`](../lib/supabase/).

`package.json` configures only `dev`, `build`, and `start`; there are no lint, typecheck, test, or end-to-end scripts. [`next.config.mjs`](../next.config.mjs) sets `typescript.ignoreBuildErrors: true`, so a production build would not serve as a reliable type-check gate. No CI workflow or Vercel project configuration was found.

## 5. Feature status matrix

| Feature | Status | Evidence / key limitation |
|---|---|---|
| Patient sign-up/sign-in | **Partially implemented** | Supabase email/password UI and dashboard session check exist; profile creation/default role behavior depends on missing base schema. |
| Clinic discovery | **Partially implemented** | Authenticated patients can view open sessions; no searchable clinic directory or direct clinic-link flow. |
| Staff provisioning | **Missing** | No create/manage staff workflow or corresponding RPC was found. |
| Schedule/session management | **Partially implemented** | Admin session/schedule operations exist; doctor self-management and verified runtime behavior are absent. |
| Patient online queue registration | **Blocked** | UI invokes a function revoked from authenticated users by a later migration; it does not call the symptoms-required replacement. |
| Walk-in queue registration | **Partially implemented** | A database RPC checks membership, reserved capacity, total capacity, and allocates a token; actual database execution is unverified. |
| Shared staff queue display | **Partially implemented** | Initial dashboard query includes entries, but subsequent `refreshStaff()` reloads only `list_clinic_walk_ins`; online entries disappear from the refreshed queue. |
| Realtime queue updates | **Partially implemented** | Subscriptions exist; no runtime test, publication configuration, or verified tenant-scoped delivery. |
| SOS request/approval | **Partially implemented** | Request and approval exist; rejection, complete audit, prescribed ordering, and SOS warning are missing. |
| No-show / standby / reactivation | **Missing** | A `no_show` state exists, but no grace timer, two-position push-back, standby state, or reactivation flow was found. |
| Consultation and history | **Partially implemented** | Consultation/history forms and guarded RPCs exist; online queue visibility and doctor patient search/workspace remain incomplete. |
| Uploads and downloads | **Partially implemented** | Private bucket/policies exist; server-side file validation and pre-consultation doctor access are not established. |
| Prescription PDF | **Partially implemented** | Structured data persists; PDF is locally generated, not stored privately. |
| Analytics | **Missing** | No persisted-record analytics feature found. |
| AI clinical summary | **Partially implemented / Not verifiable** | API route exists; no UI caller found, provider configuration is unverified, and role/record authorization is insufficient. |

## 6. Database audit

The repository contains these seven migrations, in filename order:

1. [`202610180001_clinicflow_queue_foundation.sql`](../supabase/migrations/202610180001_clinicflow_queue_foundation.sql)
2. [`202610180002_clinicflow_admin_doctors.sql`](../supabase/migrations/202610180002_clinicflow_admin_doctors.sql)
3. [`202610180003_clinicflow_medical_workflows.sql`](../supabase/migrations/202610180003_clinicflow_medical_workflows.sql)
4. [`202610180004_clinicflow_medical_document_access.sql`](../supabase/migrations/202610180004_clinicflow_medical_document_access.sql)
5. [`202610180005_clinicflow_compulsory_symptoms.sql`](../supabase/migrations/202610180005_clinicflow_compulsory_symptoms.sql)
6. [`202610180006_clinicflow_sos_priority.sql`](../supabase/migrations/202610180006_clinicflow_sos_priority.sql)
7. [`202610200001_clinicflow_walk_ins.sql`](../supabase/migrations/202610200001_clinicflow_walk_ins.sql)

**Schema evidenced in those files:** queue enums `queue_status` and `registration_source`; `doctor_schedules`, `queue_sessions`, and `queue_entries`; medical histories/documents, consultations, prescriptions/items; and `walk_in_patients`. Constraints include session/token uniqueness, session/patient uniqueness, schedule and capacity checks, file metadata constraints, and an exclusive patient-vs-walk-in identity constraint. Queue allocation/status, schedule/session, SOS, medical-record, and consultation/prescription RPCs are present. The medical workflow migration creates a private `medical-documents` bucket and associated policies.

**Major schema limitation:** None of the tracked migrations creates `profiles`, `clinics`, or `clinic_memberships`, even though later migrations reference them. There is no generated Supabase database type file. No queue-transition audit table, standby enum/state, or stored EWT calculation was found. No live schema, migration history, actual RLS state, storage bucket configuration, or Realtime publication could be verified.

The project [`README.md`](../README.md) says an “initial migration” creates identity and clinic tables, but no such migration is in the repository. It also says queues, storage, and medical records remain for later, although migrations for those features are present. That README is stale or assumes untracked/external migrations; reconcile it against the actual target database before relying on it.

## 7. Security audit

- **Authentication:** Login and signup use Supabase Auth. The dashboard independently calls `auth.getUser()` and redirects unauthenticated users. Middleware delegates to [`lib/supabase/proxy.ts`](../lib/supabase/proxy.ts), which currently returns `NextResponse.next()` without refreshing a session. The dashboard check is meaningful, but full protected-route behavior was not tested.
- **Roles and tenant isolation:** Several RPCs check `auth.uid()` and clinic membership, and the tracked migrations enable RLS on queue/medical tables. This is positive static evidence, not a complete RLS audit: the underlying membership/profile schema and policies are absent from the repository, and no database was available to test cross-clinic denials.
- **Clinical data:** Medical policies generally exclude receptionists from clinical records, consistent with the SRS. Clinic Admins and Super Admins are granted access to clinical records in several policies. Whether this is the intended least-privilege model should be confirmed.
- **Storage:** The medical-document bucket is configured private in the migration. Patient and clinician access policies exist, but a doctor's read access relies on a consultation already existing for that patient/clinic; that can block review of a newly uploaded document before consultation. The browser performs file-type/size checks, but server-enforced content validation was not evidenced.
- **AI route:** [`app/api/clinical-summary/route.ts`](../app/api/clinical-summary/route.ts) requires authentication, but does not verify Doctor role, clinic membership, or authorization to the records represented by the submitted `history` body. It forwards caller-supplied content to the configured model. The only input bound is slicing an array to ten elements; no schema/size validation or rate limit was found. Its broad catch returns a success-shaped fallback. No application caller was found, so the feature is not demonstrated as integrated.
- **Secrets/configuration:** Source uses `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` or `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and `NEXT_PUBLIC_DEV_SUPABASE_REDIRECT_URL`. No `.env.example` or checked-in `.env` file was present, and no secret values were read or printed. AI provider configuration and hosted environment values are **Not verifiable**.

## 8. Queue integrity audit

- **Allocation/capacity:** The tracked RPCs lock the session row before checking limits and assigning `max(token)+1`; the unique `(session_id, token)` constraint is a further safeguard. This is a sound static approach **if all registration paths use those RPCs**. Runtime concurrency was not tested.
- **Patient registration:** **Blocked** under the tracked migration sequence: the UI calls `register_for_queue`, while the compulsory-symptoms migration revokes that function for authenticated users and exposes `register_for_queue_with_symptoms`. The UI does not submit the required symptom field to the replacement.
- **Walk-ins/shared queue:** The later `create_walk_in` overload stores walk-in identities separately and creates `queue_entries` in the same session. It checks walk-in reserve and total capacity. However, refreshed staff data comes only from `list_clinic_walk_ins`, so online entries are omitted after refresh; staff cannot reliably operate the complete shared queue.
- **Online capacity/reserve:** Session totals and separate online/walk-in limits exist, but the SRS's approximate 40–50% reserve is not enforced as a ratio. Closed/full rejection is present in RPCs, but the visible session count is total registrations, not a demonstrated remaining-online count.
- **Ordering/EWT:** `call_next_queue_entry` orders by urgency then creation time. Patient-visible position is explicitly unavailable; the displayed EWT is a fixed per-entry estimate rather than the SRS formula. No elapsed consultation time or recalculation path was found.
- **SOS:** The request/approval RPC path exists, but direct urgent registration is accepted by the database function; approval does not persist a decision actor/outcome or implement the SRS's exact “directly behind the active consultation” ordering. No rejection flow was found.
- **No-show:** The schema supports a `no_show` status and `called_at`, but code permits staff to set no-show without enforcing a grace period. The detailed 3-minute/two-position/standby/reactivation behavior described in other repository instructions is absent.

## 9. Testing and deployment audit

**Checks actually performed:** read-only file inventory and targeted source/migration searches. The environment reported `pnpm` unavailable and `node_modules` absent. No build, lint, typecheck, unit test, integration test, browser test, or migration was run. No connection was made to Supabase. `git status --short` was attempted and failed because this directory is not a Git repository.

The only scripts defined in `package.json` are `dev`, `build`, and `start`; there are no test or lint scripts. No build was run because dependencies are unavailable and this was a read-only audit. The build config also ignores TypeScript errors.

**Deployment blockers:** no verified base-schema bootstrap, environment-variable configuration, Vercel project configuration, migration-to-live-schema reconciliation, RLS/storage/Realtime runtime tests, or role-based smoke tests. A successful build alone would not establish release readiness.

Files not inspected in detail: `pnpm-lock.yaml`, `app/globals.css`, `components/ui/button.tsx`, `lib/utils.ts`, and `.github/agents/*`. Their contents do not establish the unverified database or runtime behavior described above.

## 10. Prioritized blockers

### Critical
1. **Repository cannot establish a clean database setup.** Tracked migrations reference `profiles`, `clinics`, and `clinic_memberships`, but do not create them. The README asserts a foundational migration that is not present. A clean install/restore cannot be established from this repository alone.
2. **Patient queue registration is incompatible with the tracked migration sequence.** The UI invokes a function revoked from authenticated users; the symptoms-required replacement is not called. This blocks the primary patient queue journey if the relevant migrations are applied.

### High
1. **Incomplete staff queue data path.** Refresh loads only walk-ins, so online entries disappear from the staff queue after reload/Realtime refresh, undermining the shared-queue workflow.
2. **Queue priority is not protected by SOS approval alone.** The database accepts urgent priority on patient registration; approval lacks rejection/audit and does not implement the SRS order.
3. **No-show lifecycle is not implemented.** Grace-period enforcement, push-back, standby, reactivation, and auditable transitions are absent.
4. **Clinical file access may block the treating doctor before consultation.** Document policies depend on an existing consultation.
5. **AI summary authorization is insufficient.** Any authenticated user can submit arbitrary history content to the summary route; it does not authorize the doctor/patient/clinic relationship.

### Medium
1. **EWT and live position do not meet the SRS.** Position is unavailable; EWT is a fixed per-entry estimate, not calculated from the queue.
2. **Prescription PDF is not stored privately.** The browser generates a local download; there is no persisted private PDF access flow.
3. **Analytics and staff provisioning are missing.**
4. **Type errors can be ignored by production build configuration.**
5. **Landing-page queue/clinic figures are hardcoded.** They risk being mistaken for actual operational data, contrary to the SRS's real-data safeguard.

### Low
1. **SRS and docs contain unresolved wording/behavior conflicts** listed below; implementation should wait for owner decisions.
2. **README and repository migration inventory disagree**, complicating setup and deployment.

## 11. Recommended implementation sequence

1. **Establish the authoritative database baseline first.** Obtain the target environment's migration history/schema in a non-production context; reconcile it with the tracked migrations and role/RLS definitions. Do not apply migrations to a live project as part of this audit.
2. **Smallest safe vertical slice: one authenticated patient and one receptionist registering into the same session.** Resolve the symptom-form requirement, wire the patient UI to the authorized atomic RPC, retain shared capacity/token semantics, show both entry types after refresh, and test duplicate/concurrent registration and authorization.
3. **Complete queue state and patient updates.** Implement queue ordering and formula-based EWT/position, ensure scoped Realtime behavior, and add explicit audited transitions.
4. **Resolve SOS and no-show behavior.** Enforce who can assign urgency, add approval/rejection outcomes and audit, then implement the owner-approved missed-turn policy.
5. **Complete clinical records and documents.** Establish authorized doctor access before consultation, enforce upload validation server-side, preserve originals, and align walk-in consultations/prescriptions.
6. **Persist prescription PDFs privately**, with owner/doctor authorization and tests.
7. **Implement persisted analytics** and, only if approved/configured, secure the AI-summary workflow.
8. **Release hardening:** automated checks, cross-clinic/patient denial tests, storage/Realtime tests, staging smoke checks, and deployment configuration review.

## 12. Owner decisions required

1. Is the symptom form **mandatory** or optional? The SRS says both: §4.3 says “mandatory symptom form,” while §4.6 says the “symptom form is optional.”
2. Which missed-turn policy is authoritative? The SRS says one grace period followed by receptionist decision; [`AGENTS.md`](../AGENTS.md) and [`docs/DOMAIN_RULES.md`](DOMAIN_RULES.md) specify a 3-minute grace period, first miss moved back two positions, second miss to standby, and manual reactivation.
3. Should EWT use the SRS formula exactly, or the clamped `max(0, T_standard - T_elapsed)` form in [`docs/ARCHITECTURE.md`](ARCHITECTURE.md)?
4. Should an approved SOS entry be placed directly behind the active consultation, as the SRS says, or follow the broader urgency-first behavior in the queue function?
5. Are sections 5–7 intentionally absent from [`docs/srs.md`](srs.md), and is AI summarization enabled for the approved scope? Provider configuration and privacy terms are not verifiable here.
6. Does the intended Supabase project already have foundational profile/clinic/membership migrations outside this repository, or is this repository expected to bootstrap a clean project?

**First three actions:** confirm the target schema and migration history in a safe non-production environment; resolve the symptom/no-show/EWT/SOS conflicts; then approve a narrowly scoped shared-queue registration slice with authorization and concurrency tests.
