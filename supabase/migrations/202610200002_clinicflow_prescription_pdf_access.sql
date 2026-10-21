-- Permit a treating doctor to persist only the private PDF for their finalized prescription.
-- This migration depends on the existing medical and walk-in migrations and is not applied here.

drop policy if exists "prescription_pdf_doctor_insert" on storage.objects;
create policy "prescription_pdf_doctor_insert"
on storage.objects
for insert to authenticated
with check (
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

drop policy if exists "prescription_pdf_doctor_update" on storage.objects;
create policy "prescription_pdf_doctor_update"
on storage.objects
for update to authenticated
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
)
with check (
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

drop policy if exists "medical_documents_doctor_prescription_insert" on public.medical_documents;
create policy "medical_documents_doctor_prescription_insert"
on public.medical_documents
for insert to authenticated
with check (
  uploaded_by = (select auth.uid())
  and mime_type = 'application/pdf'
  and coalesce(array_length(storage.foldername(storage_path), 1), 0) = 2
  and (storage.foldername(storage_path))[2] = 'prescriptions'
  and exists (
    select 1
    from public.prescriptions p
    join public.clinic_memberships m
      on m.clinic_id = p.clinic_id
     and m.user_id = (select auth.uid())
     and m.role = 'doctor'
    where p.id::text || '.pdf' = storage.filename(storage_path)
      and p.patient_id::text = (storage.foldername(storage_path))[1]
      and p.patient_id = medical_documents.patient_id
      and p.doctor_id = (select auth.uid())
      and p.status = 'finalized'
  )
);

create or replace function public.attach_prescription_pdf(
  p_prescription_id uuid,
  p_storage_path text
)
returns public.prescriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prescription public.prescriptions;
  v_updated public.prescriptions;
  v_expected_path text;
begin
  select * into v_prescription
  from public.prescriptions p
  where p.id = p_prescription_id
    and p.doctor_id = (select auth.uid())
    and p.status = 'finalized'
  for update;

  if not found or v_prescription.patient_id is null then
    raise exception 'finalized patient prescription unavailable';
  end if;

  if not exists (
    select 1
    from public.clinic_memberships m
    where m.clinic_id = v_prescription.clinic_id
      and m.user_id = (select auth.uid())
      and m.role = 'doctor'
  ) then
    raise exception 'doctor access required';
  end if;

  v_expected_path := v_prescription.patient_id::text
    || '/prescriptions/'
    || v_prescription.id::text
    || '.pdf';

  if p_storage_path is distinct from v_expected_path then
    raise exception 'invalid prescription PDF path';
  end if;

  if not exists (
    select 1
    from public.medical_documents d
    join storage.objects o
      on o.bucket_id = 'medical-documents'
     and o.name = d.storage_path
    where d.storage_path = v_expected_path
      and d.patient_id = v_prescription.patient_id
      and d.uploaded_by = (select auth.uid())
      and d.mime_type = 'application/pdf'
      and d.file_size between 1 and 10485760
  ) then
    raise exception 'authorized prescription PDF artifact required';
  end if;

  update public.prescriptions p
  set pdf_storage_path = v_expected_path
  where p.id = v_prescription.id
  returning * into v_updated;

  return v_updated;
end;
$$;

revoke all on function public.attach_prescription_pdf(uuid, text) from public;
grant execute on function public.attach_prescription_pdf(uuid, text) to authenticated;
