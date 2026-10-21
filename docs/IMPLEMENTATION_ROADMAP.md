# ClinicFlow Implementation Roadmap

This roadmap is ordered by dependencies. Reorder only after the read-only audit identifies the actual current state.

## Phase 0 — Establish facts
- Map app routes and role-specific screens.
- Inspect Auth and membership handling.
- Reconcile migrations, live schema, generated types, RPCs, RLS, storage, and Realtime.
- Run safe lint/typecheck/test/build commands.
- Produce a feature evidence matrix and critical blockers.

**Exit gate:** No one is guessing the current schema or claiming unverified features work.

## Phase 1 — Foundation and access control
- Confirm authentication and profile/membership lifecycle.
- Confirm server-side role and clinic authorization.
- Test RLS and cross-clinic isolation.
- Establish private storage access policies.
- Document environment setup.

**Exit gate:** Negative authorization tests pass for key roles and tenant boundaries.

## Phase 2 — Queue integrity
- Reconcile one canonical queue/session schema.
- Implement atomic registration and capacity enforcement.
- Ensure online and walk-in entries share the allocator.
- Implement allowed status transitions and audit events.
- Implement position and EWT calculations.
- Test concurrency and duplicate submissions.

**Exit gate:** Database-backed queue passes concurrent and state-transition tests.

## Phase 3 — Staff and patient queue workflows
- Patient queue status and live updates.
- Receptionist walk-in registration and override controls.
- Doctor Today’s Queue and patient search.
- SOS request/approval workflow.
- No-show grace, push-back, standby, and reactivation.

**Exit gate:** End-to-end flows work against real persisted data with authorization tests.

## Phase 4 — Consultation and records
- Patient-reported triage and source labels.
- Private medical document upload/view/download.
- Doctor consultation workspace and encounter persistence.
- Structured prescription persistence and PDF generation.
- Correct patient/doctor/reception access boundaries.

**Exit gate:** Authorized workflows pass and unauthorized access is denied.

## Phase 5 — Optional AI summary integration
Only implement if the approved scope/configuration requires it:
- Server-side provider integration, minimal data transfer, timeout/error handling.
- Source-grounded doctor-facing summaries.
- Clear AI-generated label and source access.
- No diagnosis, prescription generation, or autonomous SOS priority.
- Consultation remains usable when AI is unavailable.

**Exit gate:** Safety/fallback tests pass and provider privacy has been reviewed.

## Phase 6 — Release hardening
- Automated checks and browser smoke tests.
- Accessible responsive UI and error handling.
- Environment and migration review.
- Staging smoke test across roles.
- Critical/high security findings resolved.
- Explicit approval before production deployment.

**Exit gate:** Evidence-based release checklist completed; no claims based only on screenshots or a successful build.
