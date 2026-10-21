# ClinicFlow Domain Rules and Acceptance Criteria

**Status:** Product requirements. Implementation status must be verified separately.

## Product boundaries
- One live sequential queue per configured clinic/doctor session, with online and walk-in entries in the same queue.
- No fixed appointment clock-time slots.
- Patient signs in before browsing the clinic directory or joining a queue.
- Patients may self-register.
- No email notifications, follow-up reminders, family profiles, or simulated in-memory backend as a substitute for real persistence.

## Roles
- **Super Admin:** platform-level administration and clinic provisioning, subject to the implemented authorization model.
- **Clinic Admin/Receptionist:** clinic queue operations, walk-in registration, SOS moderation, no-show/standby management, and permitted registration details.
- **Doctor:** Today’s Queue as the main workspace, patient search, consultation workspace, authorized medical history/documents, encounter and prescription creation.
- **Patient:** own queue status, own submitted symptoms, own permitted medical records, and own prescription documents.

Every role's capabilities must be enforced server-side and by database access policies where applicable.

## Queue
- Online and walk-in registration share the same atomic allocation mechanism and session capacity.
- Closed/full sessions reject new entries with a clear error.
- Duplicate submissions must not create duplicate queue entries.
- Queue state changes preserve history rather than silently deleting records.
- The patient view shows token/position, number ahead, and EWT when available.
- EWT is an estimate and updates after relevant state changes.

## SOS
- Patient can request urgent review.
- Request remains pending until an authorized staff member acts.
- Only an authorized approval can change queue priority.
- Store decision actor, time, and outcome.
- Never imply the SOS button contacts emergency services unless a verified implementation explicitly does so; the intended product warning is that SOS is not a substitute for emergency services.

## No-show
1. When called, start a 3-minute grace period.
2. First missed call: move the patient back by two queue positions.
3. Second missed call: move to standby.
4. Receptionist may reactivate a standby entry.
5. Make the transitions deterministic, authorized, and auditable.

## Clinical records and prescriptions
- Distinguish patient-reported information, uploaded originals, and clinician-recorded encounters/prescriptions.
- Uploads are optional; validate file type and size; preserve originals in private storage.
- Patient can access own records. Doctor access is limited to authorized clinical relationships/clinic scope. Reception is restricted to queue and registration information unless a separately approved rule grants more.
- Prescription is generated from clinician-reviewed structured data. AI must not generate prescriptions.

## AI summaries (only if the integration is enabled)
- Doctor-facing summary of submitted symptoms and available medical history.
- Identify source records and distinguish patient-reported facts from clinician-recorded facts.
- Do not invent missing information or turn uncertain statements into facts.
- Distinguish historical medication mentions from confirmed current medication.
- AI does not diagnose or autonomously determine SOS priority.
- AI failure/unavailability must not block consultation; originals and structured data remain accessible.
- Clearly label the summary as AI-generated and retain access to source material.

## Acceptance evidence
For each rule, identify code paths and tests proving the behavior. Documentation or a rendered page alone is not proof.
