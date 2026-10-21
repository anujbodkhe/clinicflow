# ClinicFlow Security and Privacy Baseline

This document is a review checklist, not a security certification.

## Identity and permissions
- Validate Supabase Auth sessions on protected server operations.
- Treat client input as untrusted; never accept a role or membership claim without verifying it.
- Apply least privilege to Super Admin, Clinic Admin/Receptionist, Doctor, and Patient.
- Enforce clinic tenant isolation in database policies and in server-side queries.
- Review RLS for every table exposed through Supabase APIs. Check SELECT, INSERT, UPDATE, DELETE separately.
- Prevent users from assigning themselves elevated roles or creating arbitrary memberships.
- Ensure Realtime subscriptions reveal only records the subscriber is permitted to read.

## Secrets and environment
- Keep service-role keys and third-party secrets server-side.
- Browser-exposed variables must contain only intentionally public values.
- Commit `.env.example` with variable names and safe placeholders only; never commit real `.env` files.
- If a secret is exposed, rotate it; do not merely delete it from the latest commit.

## Clinical information and files
- Use private storage for medical records and prescription PDFs.
- Validate allowed content types and maximum size on the server; do not rely only on file extensions.
- Verify patient/doctor/clinic access before issuing download links or serving files.
- Avoid logging symptoms, diagnoses, prescription details, document contents, access tokens, or cookies.
- Preserve source attribution: patient-reported, uploaded original, or clinician-recorded.
- Use only synthetic demo patient data for development and presentations.

## Queue integrity
- Enforce capacity and token/order allocation atomically in PostgreSQL.
- Restrict queue state transitions and SOS approval to authorized actors.
- Record actor, timestamp, and reason for sensitive overrides where appropriate.
- Protect against duplicate form submissions and concurrent registration.
- Do not allow a client to submit arbitrary queue position, priority, token number, or status.

## AI (if enabled)
- Send only the minimum necessary data to the configured provider.
- Keep provider keys server-side; set timeouts and safe failure behavior.
- Treat output as untrusted draft text, not verified clinical facts.
- Never generate diagnoses, prescriptions, or autonomous SOS decisions.
- Label summaries and keep source records accessible.
- Verify provider data retention and privacy terms before using real patient data.

## Release gate
Do not call the system production-ready until critical findings are fixed and authorization, RLS, queue concurrency, private storage, environment handling, and build/deployment behavior have been tested in a non-production environment.
