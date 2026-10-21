# Regression Test Register

Re-run linked cases after changes to the related behavior. Record the new run ID and observed result; a code change alone does not close a defect. Any decision-blocked case remains blocked until its expected behavior is approved.

| Regression ID | Scenario to rerun | Permanent test case | Triggering change | Status / related bugs |
|---|---|---|---|---|
| REG-001 | Online registration enforces required symptoms; invalid submission creates no token. | TC-REG-001, TC-QUEUE-001 | Registration UI/RPC, validation, or symptom decision. | Not Run; D-01 approved; BUG-QUEUE-001 source fix still needs isolated database retest. |
| REG-002 | Concurrent online and walk-in requests allocate unique order/token and respect shared capacity. | TC-QUEUE-003, TC-QUEUE-004 | Allocator, transaction/locking, capacity, migration. | Not Run; no related bug. |
| REG-003 | Online and walk-in entries appear together after staff refresh. | TC-QUEUE-002 | Queue query, refresh, entry normalization. | Not Run; BUG-QUEUE-002 static finding, runtime unverified. |
| REG-004 | Online cap, walk-in reserve, total cap, and closed session do not produce false confirmation. | TC-QUEUE-004 | Capacity/session/availability logic. | Not Run; no related bug. |
| REG-005 | Only allowed queue state transitions succeed, with retained audit history. | TC-QUEUE-006 | Queue status RPC, role checks, state model. | Not Run; no related bug. |
| REG-006 | Patient ownership, clinic membership, and staff roles limit record access. | TC-AUTH-003, TC-STAFF-001, TC-DOC-002, TC-DOC-003, TC-SEC-001 | Auth, RLS, RPC, route, or Storage policy. | Not Run; no related bug. |
| REG-007 | Clinical record access remains clinic-scoped and unavailable to unrelated patients/doctors. | TC-DOC-002, TC-SEC-001 | Clinical queries, doctor relationship, RLS, storage. | Not Run; no related bug. |
| REG-008 | Medical-document upload/download restrictions remain correct before and after consultation. | TC-DOC-001, TC-DOC-002 | Upload, consultation linkage, bucket policy, signed URL. | Not Run; no related bug. |
| REG-009 | SOS approval alone changes priority; rejection preserves normal order and audit. | TC-SOS-001, TC-SOS-002 | SOS RPC, authorization, ordering. | Not Run; D-04 approved; isolated database retest required. |
| REG-010 | Approved grace/pushback/standby/reactivation policy is deterministic and authorized. | TC-NOSHOW-001 | Queue timer/state transition or owner decision. | Not Run; D-02 approved; database authorization and grace-boundary tests required. |
| REG-011 | Authorized doctor can create consultations and prescriptions for supported online and walk-in identities. | TC-CONSULT-001, TC-CONSULT-002, TC-RX-001 | Consultation/prescription lifecycle, patient linkage, authorization. | Not Run; no related bug. |
| REG-012 | PDF content is based on persisted reviewed prescription, the storage path uses the persisted prescription's patient ID, and only authorized users download it. | TC-RX-002 | PDF generation/path, persistence, Storage/access. | Not Run after path-source correction and hosted migration 202610200006 apply (RUN-20261021-009); authenticated upload/download retest still required; BUG-RX-001 is Ready for Retest. |
| REG-013 | AI route/input scope and safe non-blocking failure match approved enabled configuration. | TC-AI-001, TC-AI-002 | AI/provider configuration, route, UI fallback. | Blocked pending provider/privacy configuration; D-05 approves advisory-only scope. BUG-AI-001 remains Ready for Retest. |
| REG-014 | Queue helper ordering, EWT clamp, and missed-turn decisions remain deterministic. | TC-UNIT-QUEUE-001 | Queue-rule helper changes. | Passed in RUN-20261020-006; SQL/RPC parity remains unverified. |
| REG-015 | Auth Admin and demo SQL create only namespaced synthetic fixtures and can be safely rerun in non-production. | TC-SEED-001 | Demo Auth or SQL seed script changes. | Not Run; neither Auth fixture creation nor database execution has been performed. |
| REG-016 | Shared buttons give visible hover, focus, and press feedback while respecting disabled and reduced-motion states. | TC-UX-001 | Shared button component styling or interaction changes. | Not Run; source styling updated in RUN-20261021-004; browser interaction remains unverified. |
| REG-017 | Super Admin user listing returns the declared result shape; role changes are authorized, atomic with clinic memberships, and cannot remove the last Super Admin. | TC-AUTH-004, TC-STAFF-001, TC-STAFF-002 | Role-management UI/RPC, profile or membership policy, clinic creation. | User-reported failure (RUN-20261021-010); correction applied and remote migration ledger/anonymous denial verified (RUN-20261021-012). Authenticated result-shape and role-transition/browser checks remain required; BUG-STAFF-001. |


## REG-012 update — RUN-20261021-005

Root cause of the Storage RLS 400 confirmed (static). Additive migration `202610200006_clinicflow_prescription_pdf_select.sql` and client `upsert: false` change address the SELECT policy gap. Typecheck/unit tests/build pass. **Status: Not Run (migration unapplied).** Retest after staging apply with explicit owner approval, covering TC-RX-002 scenarios 1–5.
