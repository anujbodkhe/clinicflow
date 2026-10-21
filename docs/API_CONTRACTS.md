# ClinicFlow API and Operation Contracts

**Status:** Proposed behavioral contracts, not a claim that these routes/RPCs currently exist. Inspect the repository and actual Supabase schema before choosing exact endpoint names, request fields, or RPC signatures.

The current stack may use Next.js route handlers/server actions and Supabase directly from authorized server/client contexts. Do not create a separate API server just to match this document.

## Contract principles
- Every operation validates authentication and authorization on the server/database.
- Clinic scope comes from verified membership, not an untrusted client claim.
- Validate all inputs; return stable error codes and useful user-safe messages.
- Never return secrets or data outside the actor's permitted scope.
- Queue-changing operations must be atomic and safe against duplicate submissions.
- Do not expose service-role operations to the browser.

## Proposed operation catalogue

| Operation | Authorized actor | Required behavior |
|---|---|---|
| List clinic directory | Authenticated patient | Return only clinics allowed by product visibility rules; no cross-tenant private data |
| Read clinic/session status | Authenticated patient or authorized clinic staff | Return open/capacity/status information only |
| Register patient in queue | Authenticated patient | Verify open session/capacity; atomically allocate token/order; reject duplicates safely |
| Register walk-in | Authorized clinic receptionist/admin | Validate walk-in details; use same queue allocator as online registration |
| Read own queue status | Patient who owns entry | Return own token, current position, patients ahead, estimated wait |
| Read clinic queue | Authorized clinic staff | Return only entries in the actor's clinic/session scope |
| Submit triage symptoms | Authenticated patient with permitted queue/patient relationship | Store as patient-reported; validate and label source |
| Submit SOS request | Authenticated patient with permitted queue entry | Create pending request; do not change priority yet |
| Decide SOS request | Authorized receptionist/admin/doctor according to verified policy | Record decision actor/time; approved request triggers protected priority transition |
| Change queue state / call next | Authorized clinic staff or assigned doctor | Enforce allowed state transitions and write audit event |
| Reactivate standby entry | Authorized receptionist/admin | Validate session and state; restore to queue deterministically |
| Read medical history/documents | Patient for own records; authorized doctor for permitted patient | Enforce relationship, clinic scope, and private storage permissions |
| Record consultation | Authorized doctor | Persist clinician-authored encounter |
| Create prescription | Authorized doctor | Persist structured prescription linked to encounter; no AI-generated prescription |
| Generate/download prescription PDF | Patient owner or authorized clinician | Render from persisted authorized prescription; private access |
| Generate AI summary (if enabled) | Authorized doctor/server workflow | Use allowed source data; label as AI-generated; fallback to original records on failure |

## Error semantics to standardize
Use the project's existing error convention where one exists. At minimum distinguish:
- `UNAUTHENTICATED`
- `FORBIDDEN`
- `NOT_FOUND`
- `VALIDATION_ERROR`
- `SESSION_CLOSED`
- `SESSION_FULL`
- `DUPLICATE_REGISTRATION`
- `INVALID_STATE_TRANSITION`
- `CONFLICT`
- `RATE_LIMITED`
- `INTERNAL_ERROR`

Do not leak whether a protected record exists when that would disclose private information.

## Before adding an endpoint or RPC
1. Search for an existing equivalent route/action/function.
2. Inspect the current table definitions and generated types.
3. Decide whether this should be a server action, route handler, or database RPC based on existing patterns and transaction requirements.
4. Document request/response shape and authorization.
5. Add success, validation, unauthorized, forbidden, conflict, and failure tests where applicable.
