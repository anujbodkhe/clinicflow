# ClinicFlow Data Model — Reconciliation Draft

**Important:** This is a conceptual model, not an executable schema. The repository's migrations and actual Supabase schema must be inspected first. Do not create tables from this document without a reviewed mapping.

## Entity concepts
| Concept | Purpose | Key constraints to verify/design |
|---|---|---|
| `profiles` / user profile | Application identity linked to Auth | One profile per auth user; no client-controlled role escalation |
| `clinics` | Tenant boundary | Stable ID; active status/configuration |
| `clinic_memberships` | User-to-clinic role assignment | Unique user/clinic membership; privileged roles assigned securely |
| doctor/clinic association | Defines clinician scope | Must prevent access to unrelated clinic patients |
| `schedule_sessions` / queue session | One operational queue period | Clinic/doctor relationship, open/closed state, capacity, time zone |
| `queue_entries` | Online or walk-in participant in shared queue | One identity source per entry; session-scoped unique token/order; valid state transitions |
| walk-in identity/details | Reception-entered patient without an account, if supported | Minimize personal data; avoid forcing a fake Auth user |
| triage submissions | Patient-reported symptoms and duration | Author, timestamp, source label, queue/patient linkage |
| medical documents | Metadata for uploaded originals | Private storage path, size/type metadata, uploader, patient/clinic scope |
| encounters | Clinician-recorded consultation | Doctor, patient, clinic, timestamps, access policy |
| prescriptions | Clinician-reviewed medication instructions | Linked encounter and author; never generated autonomously by AI |
| SOS requests/decisions | Pending request and staff decision | Requester, decision actor/time, status; only approved decision changes priority |
| queue audit events | Record important state changes | Actor, old/new state, timestamp, reason where appropriate |

## Queue-entry identity invariant
If walk-ins can exist without a patient account, model identity explicitly. A queue entry should refer to exactly one supported identity form (for example, a registered patient OR a walk-in record), unless the actual schema deliberately uses a different normalized design. Enforce the invariant in the database, not only the UI.

## Queue allocation invariant
Token/order allocation and capacity checks must be atomic for all registration paths. Consider a session row lock or equivalent transaction-safe mechanism and appropriate unique constraints. The correct implementation depends on the current schema and Supabase/Postgres patterns.

## Schema reconciliation checklist
- [ ] Enumerate committed migrations in order.
- [ ] Inspect actual tables, columns, enums, constraints, indexes, triggers, functions/RPCs, and policies.
- [ ] Compare the live schema to migrations and generated TypeScript types.
- [ ] Identify competing table/enum/function names from old drafts.
- [ ] Confirm session capacity and token reset semantics.
- [ ] Confirm cancellation/completion/standby semantics and audit retention.
- [ ] Map every proposed entity to existing objects before drafting any migration.
- [ ] Test migration against an isolated development database before approval.
