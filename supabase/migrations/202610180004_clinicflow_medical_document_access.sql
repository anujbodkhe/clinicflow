-- Allow patients to manage only their own document metadata.
-- Preserve doctor/clinic-admin metadata visibility while keeping receptionists out.
-- Keep the medical-documents bucket private.

alter table public.medical_documents enable row level security;

drop policy if exists "medical_documents_authorized_select" on public.medical_documents;
create policy "medical_documents_authorized_select"
on public.medical_documents
for select to authenticated
using (
  patient_id = (select auth.uid())
  or exists (
    select 1
    from public.consultations c
    join public.clinic_memberships m on m.clinic_id = c.clinic_id
    where c.patient_id = medical_documents.patient_id
      and m.user_id = (select auth.uid())
      and (
        (m.role = 'doctor' and c.doctor_id = (select auth.uid()))
        or m.role in ('clinic_admin', 'super_admin')
      )
  )
);

drop policy if exists "medical_documents_patient_insert_own" on public.medical_documents;
create policy "medical_documents_patient_insert_own"
on public.medical_documents
for insert to authenticated
with check (
  patient_id = (select auth.uid())
  and uploaded_by = (select auth.uid())
  and (storage.foldername(storage_path))[1] = (select auth.uid()::text)
);

drop policy if exists "medical_documents_patient_update_own" on public.medical_documents;
create policy "medical_documents_patient_update_own"
on public.medical_documents
for update to authenticated
using (patient_id = (select auth.uid()) and uploaded_by = (select auth.uid()))
with check (
  patient_id = (select auth.uid())
  and uploaded_by = (select auth.uid())
  and (storage.foldername(storage_path))[1] = (select auth.uid()::text)
);

drop policy if exists "medical_docs_patient_update" on storage.objects;
create policy "medical_docs_patient_update"
on storage.objects
for update to authenticated
using (bucket_id = 'medical-documents' and (storage.foldername(name))[1] = (select auth.uid()::text))
with check (bucket_id = 'medical-documents' and (storage.foldername(name))[1] = (select auth.uid()::text));
