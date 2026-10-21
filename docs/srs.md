1. Product objective
ClinicFlow is a multi-clinic web platform for independent clinics . It manages a live sequential queue rather than fixed-time appointment slots. Patients join a clinic's queue online, monitor queue position and estimated waiting time, and travel when their turn approaches. Receptionists add walk-in patients to the same queue.
Delivery principle: build a genuinely functional full-stack application which is deployable. Do not substitute mock arrays, simulated backend delays, or hardcoded fake operations for real database-backed functionality.


## 2. Chosen implementation stack

| Layer | Choice | Reason / implementation note |
|---|---|---|
| Application | Next.js App Router + TypeScript | One project for UI, server-side logic, route handlers and deployment. |
| UI | Tailwind CSS, shadcn/ui, lucide-react | Fast, consistent, responsive and accessible interface. |
| Database | Supabase PostgreSQL | Persistent relational data, constraints, transactions and row-level security. |
| Authentication | Supabase Auth, email/password | Patient self-registration; staff accounts provisioned by authorized admins. |
| Private files | Supabase Storage | Private medical-history uploads and generated prescription PDFs. |
| Realtime | Supabase Realtime | Queue position and EWT updates across connected clients. |
| Validation | Zod; React Hook Form where useful | Consistent input validation on client and server. |
| AI summaries | Server-side provider adapter using an actual configured AI API | Summarize symptoms and available history; do not diagnose or generate prescriptions. |
| PDF | Deterministic PDF generation library | Render doctor-entered prescription data into a controlled template. |
| Deployment | Vercel + hosted Supabase | Simple path to an online demonstration; local development remains supported. |

**ORM decision:** Do not add Drizzle initially. Supabase's PostgreSQL client, SQL migrations, constraints, and row-level security keep the first implementation simpler. Add an ORM only if one becomes necessary.

**Secrets:** AI keys and any privileged database/service-role keys must stay server-side and never be exposed in browser code. Use environment variables and a documented `.env.example`.


3. Roles and authorization
•	Super Admin: Create/manage clinics; provision staff across clinics; platform-wide oversight and settings.
•	Clinic Admin: Manage only their authorized clinic(s); create staff accounts for their clinic; configure schedules, capacity and queues.
•	Doctor: Manage own working days/session times and online capacity; view records for authorized patients; record consultations and prescriptions.
•	Receptionist: Register walk-ins; operate queue; moderate SOS; handle missed turns. No routine access to medical records.
•	Patient: Self-register; sign in; browse clinics/doctors; join queues; submit symptoms; optionally upload records; access own history and PDFs.
Authorization must be enforced server-side and at the database/storage layer where applicable—not only by hiding UI controls. Clinic Admins cannot manage other clinics or create Super Admin accounts. Keep tenant/clinic identifiers on all clinic-scoped records.
4. Functional requirements
4.1 Authentication and clinic discovery
•	Patients self-register using an email-formatted identifier and password; a real inbox is not required for the demo if email delivery is unused and confirmation is disabled in that environment.
•	Staff accounts are created by the Super Admin or the appropriate Clinic Admin. No public staff registration.
•	Sign-in is required before patients can browse clinics or availability.
•	Support both a searchable clinic directory and direct clinic links.
•	Support multiple clinics with clinic-specific settings, queues, staff assignments and protected records. Seed one or two populated demo clinics.
4.2 Schedules and capacity
•	Doctors configure working weekdays, session start/end times and a manual maximum for online registrations; authorized Clinic Admins can configure/manage clinic queue limits.
•	Online and walk-in patients share one total session capacity and one sequential queue.
•	Reserve approximately 40–50% of the intended session capacity for walk-ins. Example: planned capacity 20, online cap 12, walk-in reserve 8.
•	Show remaining online places before joining. Reject registration when the online cap or total session capacity is reached.
•	Authorized staff can close online registration early. A full queue offers no false confirmed token; the patient can look for another doctor/clinic.
•	Queue closes at the end of the clinic day/session; the next session starts a fresh queue. Historical visits remain stored.
4.3 Queue lifecycle and atomic tokens
•	Patient journey: sign in → choose clinic → choose doctor → mandatory symptom form → optional history upload → capacity check → confirmed token → live queue view.
•	Walk-ins are added to the same queue and consume shared capacity, including reserved walk-in places.
•	Token assignment must be concurrency-safe and atomic in the database so simultaneous online and walk-in registrations cannot receive duplicate tokens or exceed capacity.
•	Queue changes include registration, consultation start/end, approved SOS priority movement, manual staff controls and missed-turn handling.
•	Missed turn: one grace period, then the receptionist decides manually what happens next.
•	Daily queues reset for the next session; records and previous tokens remain in history.
4.4 EWT and realtime
•	Initial configurable constants: standard consultation = 10 minutes; urgent consultation = 15 minutes.
•	EWT = (T_std − T_elapsed) + (N_standard × T_std) + (N_urgent × T_urgent).
•	Recalculate on consultation start/end and queue order changes, including approved SOS requests.
•	Show live queue position and estimated waiting time inside the app. No email notifications or automated follow-up reminders.
•	Clearly label EWT as an estimate, not a guaranteed consultation time.
4.5 SOS moderation
•	Patient can submit an SOS request while waiting.
•	Authorized clinic staff review before priority movement. Approved request is inserted directly behind the active consultation; rejected request stays in normal order.
•	Display a clear notice that SOS is not a substitute for emergency services. Do not imply autonomous clinical triage.
4.6 Medical history and symptom form
•	Distinguish patient-reported information, uploaded documents, and clinician-recorded visits/prescriptions.
•	History upload and symptom form  is optional. Preserve originals for doctor review; support validated PDF and common image formats with size/type limits.
4.7 Consultations and prescription PDF
•	Doctor records consultation information and structured medication details: name, strength where relevant, dose, frequency, duration and instructions.
•	Generate a deterministic, professional PDF from doctor-entered data; doctor reviews/finalizes it.
•	Store the PDF privately in the patient's vault for later viewing/downloading.
•	Describe the PDF as a patient reference/consultation record; do not claim it automatically replaces a legally compliant prescription.
4.8 Analytics
•	Show daily patient volume, peak hours, average consultation duration, common recorded case categories and queue completion statistics.
•	Analytics derive from actual stored records. Do not present hardcoded demo figures as genuine data.


8. Non-negotiable safeguards
•	Never put Supabase service-role keys, AI API keys, or other secrets in client-side code.
•	Do not rely on hidden buttons for security; enforce permissions server-side and with database/storage policies.
•	Use private storage for medical documents and prescription PDFs.
•	Use atomic database operations for queue token generation and capacity checks.
•	AI output is advisory summarization only; preserve source records and allow care to continue if AI fails.
•	Use real persisted data for queue, visits and analytics. Seed data is permitted only as labelled demo data.
•	Do not add automated follow-up reminders, family profiles, fixed-time booking, AI prescriptions or other excluded features.
•	Before real-world clinical use, obtain appropriate security, privacy, operational and legal review; a student demo is not automatically production-certified.
9. Demo checklist
•	Sign in as Super Admin and create a clinic.
•	Create a Clinic Admin and doctor; configure the doctor's working session and online capacity.
•	Register a patient and join the queue after completing symptoms.
•	Register a walk-in as Receptionist and verify shared capacity and token order.
•	Open the patient queue view on another browser/device and verify live position/EWT updates.
•	Fill the online capacity and verify new online registrations are blocked while reserved walk-in capacity remains available.
•	Submit and moderate an SOS request; verify approved/rejected behavior.
•	Miss a turn and verify the receptionist can decide the next action.
•	Upload a medical-history document, and verify it remains accessible to the authorized doctor.
•	Record a consultation, finalize a prescription PDF and verify patient-only access.
•	Check analytics against the persisted demonstration records.
•	Attempt unauthorized cross-clinic and cross-patient access and verify denial.
