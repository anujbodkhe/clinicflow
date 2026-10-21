# Synthetic Test Data

Use fictional values only. Do not use real patient records, real email addresses owned by people, copied production rows, or production credentials. Fixtures must be created only in a dedicated local/non-production environment with explicit authorization.

## Minimum synthetic fixture set

- **Clinics:** `clinic-a` and `clinic-b`, each with distinct synthetic names/IDs and independent settings.
- **Users:** one Super Admin; Clinic A and Clinic B Clinic Admins; one receptionist per clinic; one doctor per clinic; two patients in Clinic A and one patient in Clinic B. Assign roles only through the approved test setup.
- **Schedules/sessions:** one open, one full, one closed session; include distinct online cap, walk-in reserve, and total capacity. Use fixed test times/timezone and a controllable clock where possible.
- **Queue entries:** multiple online and receptionist-created walk-in entries in the same session; standard/urgent examples only after SOS rules are approved; duplicate, near-capacity, called, and completed fixtures.
- **Clinical records:** synthetic patient-reported symptom text, a clinician-recorded encounter, and a finalized structured prescription. Use obviously fictional, non-clinical sample text and medication names appropriate only for test data; do not represent it as care guidance.
- **Documents:** locally generated harmless PDFs and images with synthetic text; include allowed size/type, too-large, unsupported-type, and MIME/extension-mismatch fixtures. Never use actual scans or patient documents.
- **AI:** only if owner approves D-05 and provider/privacy setup. Use synthetic facts only; never put clinical payloads or provider secrets in logs.

## Isolation and cleanup

- Prefer an ephemeral local database/app environment or dedicated disposable Supabase project with its own Auth, Storage bucket, and Realtime configuration.
- Verify project URL and environment name before any write. Never point a test command at a production project; do not infer environment from a variable name alone.
- No database reset, truncation, broad deletion, migration apply, or fixture seeding is authorized by this document. Define and review a scoped fixture/cleanup mechanism before integration tests.
- Keep fixtures namespaced by run and clinic where supported. Clean only explicitly identified test-owned records/objects after confirming ownership and environment; preserve evidence without sensitive payloads.
- Missing credentials, base schema, or isolated target makes the affected test `Blocked`; do not use a shared/staging/production environment as a shortcut.

## Environment variable names

The source currently references `NEXT_PUBLIC_SUPABASE_URL` and either `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` or `NEXT_PUBLIC_SUPABASE_ANON_KEY`. These are names only; this document contains no values. The AI route/provider does not show a conventional explicit key in the inspected source; confirm configured provider requirements only after D-05 is resolved. No `.env.example` was found in the inspected repository. Never print or commit values.

## Test prerequisites

- [`../supabase/demo-data/`](../supabase/demo-data/) contains optional synthetic demo fixtures, not migrations. Create the listed Auth users with `create-demo-users.mjs` using the Auth Admin API (or manually in Dashboard), then run `hosted-demo-seed.sql` only in a dedicated non-production project. Review both safety gates; never use production or real patient data.
- **Unit:** approved runner and deterministic, synthetic fixtures; no database required for pure logic.
- **Integration/security:** confirmed migration base and order (D-06), dedicated non-production DB/Auth/Storage/Realtime, synthetic role accounts, and a reviewed fixture/cleanup procedure.
- **E2E/manual:** local or isolated deployed app connected only to test services; test users per role; browser/test harness and safe reset strategy.
- **AI:** owner approval, provider/privacy configuration, synthetic-only input, and bounded failure controls.

No current test should connect to production, change real accounts, or apply migrations to a live project.
