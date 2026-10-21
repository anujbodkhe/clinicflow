# ClinicFlow Decisions

**Purpose:** Record approved decisions and unresolved conflicts so agents do not settle product behavior by assumption.  
**Status date:** 2026-10-20. The user implementation directive resolves D-01 through D-06; D-07 remains open.

## Approved constraints evidenced by current requirements

These are documented constraints, not proof of implementation:

- The product is a multi-clinic live sequential queue, not fixed-time appointment booking ([`srs.md`](srs.md) §1).
- Patient and receptionist walk-in entries share one session queue and database-atomic capacity/token allocation (SRS §4.2–4.3).
- Authorization must be server-side and enforced at database/storage layers where applicable (SRS §3, §8).
- Clinical files are private; AI must not diagnose or generate prescriptions; operational analytics must use persisted records (SRS §2, §8).
- Do not add excluded functionality such as email follow-ups, family profiles, fixed-time booking, or fake persistence (SRS §8; [`AGENTS.md`](../AGENTS.md)).

## User-approved decisions

The following defaults were explicitly supplied in the user's implementation directive. They clarify the conflicting source requirements without rewriting the SRS.

| ID | Approved behavior | Consequences and limits |
|---|---|---|
| D-01 | Patient online queue registration requires a non-empty symptom description, enforced in the UI and database RPC. Receptionist walk-in symptoms may be blank; the system must not invent a value. | Resolves the SRS §4.3 / §4.6 conflict for online registration. Walk-in registration remains a distinct path. |
| D-02 | A called entry receives a three-minute grace period. First missed call returns it to waiting behind up to two waiting entries. Second miss moves it to standby. An authorized receptionist or clinic administrator may reactivate it at the end of the queue. Record actor, time, and outcome. | The detailed Domain Rules supersede the SRS §4.3 one-grace/manual-discretion wording. |
| D-03 | EWT is clamped and deterministic: for each entry ahead, count 10 minutes for standard work and 15 minutes for approved SOS work; for an active consultation count `max(0, duration - completed_elapsed_minutes)`. A called entry consumes its full estimate until consultation starts. | EWT is an estimate, not an arrival-time promise. Elapsed time uses whole completed minutes; the result is never negative. |
| D-04 | An approved SOS entry follows the active called/in-progress entry. If there is no active entry, it is next. Multiple approved requests are ordered by decision time (FIFO); unapproved requests do not change order. | Only authorized clinic staff approval changes priority. SOS does not contact emergency services. |
| D-05 | Advisory clinical summaries are in scope only when a provider and data/privacy configuration are explicitly enabled. A doctor initiates them; summaries identify source records, do not diagnose or prescribe, and never block consultation. AI cannot approve or prioritize SOS. | Provider selection, credentials, and external data-processing approval are still required before enabling the integration in any environment. |
| D-06 | The repository owns the foundational identity/tenant schema and migration sequence for clean local Supabase setup. The user authorizes repository-side schema work, not application to any hosted or unknown database. | The new migration chain is a proposed local source of truth until it is applied and validated in an isolated local Supabase stack. |

## Unresolved decision

| ID | Conflict / question | Sources and exact difference | Impact | Needed from owner |
|---|---|---|---|---|
| D-07 | Are SRS sections 5–7 intentionally absent? | `docs/srs.md` moves from §4.8 to §8. | Completeness of requirements traceability. | Provide missing sections or confirm numbering omission. |

## Decision recording protocol

Do not treat repository changes as proof of runtime behavior or hosted-database approval. Keep the SRS text intact; record reconciliations in this file, [`REQUIREMENTS_TRACEABILITY.md`](REQUIREMENTS_TRACEABILITY.md), [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md), and applicable tests. Do not mark a check passed without observed evidence.
