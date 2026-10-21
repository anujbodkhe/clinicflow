# ClinicFlow Testing and Acceptance Plan

The persistent test case, regression, execution, bug, and environment records are maintained under [`tests/README.md`](../tests/README.md). Use the current repository tooling and record evidence there; this overview does not imply that any workflow has been tested.

## Start with the repository's existing commands
Inspect `package.json`, lockfile, test configuration, and CI workflow. Run only commands that exist. Do not claim a check passed if it was not run.

Typical checks, only if configured:
- lint
- typecheck
- unit tests
- integration tests against an isolated Supabase project
- production build
- browser end-to-end tests

## Required scenarios
### Authentication and tenant isolation
- Anonymous visitor cannot access protected patient/clinic records.
- Patient A cannot read Patient B's records or queue entry.
- A member of Clinic A cannot access Clinic B's queue or documents.
- Receptionist cannot access full clinical history unless explicitly authorized.
- User cannot self-assign Doctor, Clinic Admin, or Super Admin role.

### Queue
- Online and walk-in registrations appear in the same session queue.
- Concurrent registrations cannot allocate duplicate token/order values.
- Capacity cannot be exceeded under concurrent load.
- Closed sessions reject new entries.
- Duplicate submission does not create duplicate active entries.
- Queue position/EWT changes after call-next, completion, approved SOS, cancellation, push-back, standby, and reactivation as applicable.
- Verify user-approved D-02 in [`DECISIONS.md`](DECISIONS.md): three-minute grace, first-miss pushback, second-miss standby, authorized reactivation, and audit history. The source migration is not runtime evidence.

### SOS and clinical workflows
- SOS submission creates a pending request only.
- Unauthorized user cannot approve/reject an SOS request.
- Rejection does not reorder queue.
- Consultation and prescription creation require an authorized doctor.
- Prescription PDF matches persisted clinician-reviewed data.
- Unauthorized user cannot download a private medical document or prescription.

### AI summaries, only if enabled
- Summary references source information and does not invent missing facts.
- Historical medication mentions are not asserted as current medication without evidence.
- Timeout/malformed output/provider failure does not block consultation.
- Original structured symptoms and uploaded documents remain accessible.

### UX and resilience
- Loading, empty, validation, offline/network failure, and server error states are understandable.
- Failed save never displays success.
- Form submissions preserve recoverable user input.
- Keyboard and screen-reader labels are usable.
- Layout works on mobile, tablet, and desktop widths.

## Acceptance report format
For each scenario report: `PASS`, `FAIL`, `BLOCKED`, or `NOT RUN`; test method; evidence; and follow-up. Do not treat manual visual inspection as proof of backend authorization.
