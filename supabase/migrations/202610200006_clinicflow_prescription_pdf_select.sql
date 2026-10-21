-- Allow the treating doctor to read (SELECT) the exact private prescription PDF
-- object they are about to write, so Storage upsert can resolve the conflict check.
--
-- Root cause addressed:
--   Storage's `upsert: true` internally requires SELECT + INSERT + UPDATE on the
--   target object path.  The existing INSERT and UPDATE policies
--   (`prescription_pdf_doctor_insert` / `prescription_pdf_doctor_update`) were
--   correctly predicated on the finalized prescription row.  However, there was
--   no SELECT policy that covered the prescription-subfolder path when accessed by
--   the treating doctor.
--
--   The only existing SELECT policy (`medical_docs_authorized_read` from migration
--   202610180003) grants doctors access through a JOIN chain that requires a
--   matching row already in `public.medical_documents`.  For a first-time upload
--   that row does not exist yet, so SELECT fails, and Storage rejects the INSERT
--   with "new row violates row-level security policy" (HTTP 400).
--
-- Fix:
--   Add a narrowly scoped SELECT policy on `storage.objects` for the treating
--   doctor.  It mirrors the exact same finalized-prescription/clinic-membership
--   predicate already used in the INSERT/UPDATE policies, without any dependency
--   on a pre-existing `medical_documents` metadata row.
--
-- Security impact:
--   - No bucket is made public.
--   - No broad "authenticated" select is added.
--   - The policy is restricted to:
--       • bucket 'medical-documents'
--       • exactly 2 path segments (patient-uuid/prescriptions/<rx-uuid>.pdf)
--       • second segment must be 'prescriptions'
--       • file name must be '<prescription-id>.pdf'
--       • first segment (folder) must equal prescriptions.patient_id
--       • prescription must be finalized and owned by auth.uid()
--       • auth.uid() must have an active 'doctor' membership in the prescription's clinic
--   - This grants the doctor read access to only the single file they wrote, for
--     the finalized prescription belonging to their patient in their clinic.
--   - Patient download is still served by the existing `medical_docs_authorized_read`
--     policy (folder[1] = auth.uid()), which already works for patients because
--     the patient-folder IS their own UUID.
--   - Unrelated doctors and patients remain denied by all policies combined.
--
-- This migration is additive and does not drop or alter any existing policy,
-- table, or data.  It must not be applied to any hosted environment without
-- explicit owner approval of the exact SQL below.

drop policy if exists "prescription_pdf_doctor_select" on storage.objects;
create policy "prescription_pdf_doctor_select"
on storage.objects
for select to authenticated
using (
  bucket_id = 'medical-documents'
  and coalesce(array_length(storage.foldername(name), 1), 0) = 2
  and (storage.foldername(name))[2] = 'prescriptions'
  and exists (
    select 1
    from public.prescriptions p
    join public.clinic_memberships m
      on m.clinic_id = p.clinic_id
     and m.user_id = (select auth.uid())
     and m.role = 'doctor'
    where p.id::text || '.pdf' = storage.filename(name)
      and p.patient_id::text = (storage.foldername(name))[1]
      and p.doctor_id = (select auth.uid())
      and p.status = 'finalized'
  )
);
