# ClinicFlow Architecture

**Status:** Intended architecture. Validate against the repository before treating any component as implemented.

## 1. Product shape
ClinicFlow is a multi-clinic, responsive web application that coordinates a live sequential queue for online registrations and receptionist-entered walk-ins. It is not a fixed appointment-slot booking system.

## 2. Intended stack
- Web application: Next.js App Router + TypeScript.
- UI: Tailwind CSS, shadcn/ui, lucide-react.
- Backend/data services: Supabase PostgreSQL, Auth, private Storage, and Realtime.
- Hosting: Vercel for the web application; Supabase-managed services for configured backend resources.
- AI summarization: only if configured and explicitly enabled; server-side integration with a safe fallback. Never use AI to diagnose, generate prescriptions, or autonomously approve SOS priority.

Verify installed versions and actual service configuration. Do not introduce a separate API server, Redis, or custom WebSocket service unless a demonstrated requirement warrants it.

## 3. Logical layers
1. **Presentation:** patient, doctor, clinic-admin/receptionist, and super-admin screens.
2. **Server/application:** Next.js server components, route handlers, server actions, or existing server-side modules. Sensitive operations validate session, role, clinic membership, inputs, and state transitions.
3. **Data/services:** PostgreSQL constraints and transactions/RPCs; Supabase Auth; private Storage; Realtime subscriptions scoped to authorized data.

Realtime is a delivery mechanism, not the source of truth. The database remains authoritative.

## 4. Trust boundaries
- Browser/client: untrusted. It may display data and request actions, but cannot decide authorization, queue priority, token allocation, clinic membership, or clinical permissions.
- Next.js server: validates the authenticated actor and requested operation. Do not expose service-role secrets to the client.
- PostgreSQL/RLS: enforce tenant and row access where feasible; critical queue invariants must also be protected at database level.
- Storage: private by default; authorization required for uploads/downloads.
- External AI service (if enabled): receive only the minimum necessary clinical data; handle timeout, unavailable configuration, and malformed output. Do not treat output as verified clinical fact.

## 5. Main domain entities (conceptual, not final SQL)
- User profile and clinic membership
- Clinic and clinician/doctor association
- Doctor schedule / queue session
- Queue entry (online patient or walk-in identity)
- Patient-reported symptom/triage submission
- Patient medical document and clinician-recorded encounter
- Prescription and prescription line items
- SOS request and staff decision
- Queue state transition/audit event

Actual names, relationships, nullability, and enum values must be derived from the existing migrations/schema. Do not create a parallel model merely to match these conceptual names.

## 6. Core workflows
### Patient joins queue
Authenticate -> verify clinic/session open and capacity -> validate eligibility -> atomically allocate queue order/token -> persist entry -> publish authorized update -> display current position/EWT.

### Receptionist registers walk-in
Authorize receptionist for clinic -> validate walk-in identity and required fields -> use the same queue-allocation operation as online entry -> persist and publish update. Avoid separate token counters.

### SOS request
Patient submits request -> persist pending request -> authorized staff reviews -> approval/rejection is recorded -> if approved, a database-protected queue transition changes priority -> notify authorized clients. The system must not describe this as a replacement for emergency services.

### Consultation and prescription
Doctor verifies active clinic/patient relationship -> reviews patient-reported data and records -> records encounter -> creates prescription from clinician-entered/reviewed fields -> generates PDF from persisted prescription -> stores privately and grants authorized access.

### No-show
Turn called -> 3-minute grace period -> first missed call moves the entry back by two positions -> second missed call moves it to standby -> receptionist can reactivate. State changes and actor/timestamp should be auditable.

## 7. Queue ordering and EWT
- Use a database transaction or atomic RPC for token/order assignment and capacity enforcement.
- Do not allocate with client-side `MAX(token_number) + 1`.
- Confirm whether token numbers reset per clinic session; never assume reset semantics without inspecting current requirements/schema.
- The intended deterministic EWT rule is:
  `EWT = max(0, T_standard - T_elapsed) + (N_standard × T_standard) + (N_urgent × T_urgent)`
  Initial reference values in project notes: standard = 10 minutes, urgent = 15 minutes. These are estimates/configuration defaults, not clinical facts. Verify how active consultation elapsed time and priority order are represented in the actual implementation.
- Recalculate after relevant queue transitions, consultation start/end, and approved SOS priority changes.
- Label wait time as an estimate, not a guaranteed appointment time.

## 8. Operational qualities
- Tenant isolation across all reads/writes and Realtime channels.
- Explicit loading/error/empty states.
- Idempotent handling for duplicate form submissions where practical.
- Audit trail for sensitive and queue-changing actions.
- Accessible responsive UI.
- Observability without sensitive clinical payloads in logs.
