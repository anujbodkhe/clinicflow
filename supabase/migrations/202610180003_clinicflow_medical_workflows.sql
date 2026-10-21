-- ClinicFlow Prompt 3: medical workflows. Additive and backward-compatible.

create table if not exists public.patient_medical_histories (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  allergies text,
  conditions text,
  medications text,
  symptoms text,
  notes text,
  source text not null default 'patient' check (source in ('patient','clinician')),
  recorded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.medical_documents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null check (mime_type in ('application/pdf','image/jpeg','image/png','image/webp')),
  file_size integer not null check (file_size between 1 and 10485760),
  created_at timestamptz not null default now()
);

create table if not exists public.consultations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete restrict,
  doctor_id uuid not null references public.profiles(id) on delete restrict,
  clinic_id uuid not null references public.clinics(id) on delete restrict,
  queue_entry_id uuid references public.queue_entries(id) on delete set null,
  symptoms text not null default '',
  clinical_notes text not null default '',
  diagnosis_notes text not null default '',
  status text not null default 'draft' check (status in ('draft','finalized')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  finalized_at timestamptz
);

create table if not exists public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references public.consultations(id) on delete restrict,
  patient_id uuid not null references public.profiles(id) on delete restrict,
  doctor_id uuid not null references public.profiles(id) on delete restrict,
  clinic_id uuid not null references public.clinics(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','finalized')),
  pdf_storage_path text,
  created_at timestamptz not null default now(),
  finalized_at timestamptz
);

create table if not exists public.prescription_items (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  medicine_name text not null,
  strength text not null,
  dose text not null,
  frequency text not null,
  duration text not null,
  instructions text not null default ''
);

alter table public.patient_medical_histories enable row level security;
alter table public.medical_documents enable row level security;
alter table public.consultations enable row level security;
alter table public.prescriptions enable row level security;
alter table public.prescription_items enable row level security;

drop policy if exists "patient_history_select_authorized" on public.patient_medical_histories;
create policy "patient_history_select_authorized" on public.patient_medical_histories for select to authenticated using (patient_id = (select auth.uid()) or exists (select 1 from public.consultations c where c.patient_id = patient_medical_histories.patient_id and ((c.doctor_id = (select auth.uid()) and exists (select 1 from public.clinic_memberships doctor_membership where doctor_membership.clinic_id = c.clinic_id and doctor_membership.user_id = (select auth.uid()) and doctor_membership.role = 'doctor')) or exists (select 1 from public.clinic_memberships m where m.clinic_id = c.clinic_id and m.user_id = (select auth.uid()) and m.role in ('clinic_admin','super_admin')))));
drop policy if exists "patient_history_insert_own" on public.patient_medical_histories;
create policy "patient_history_insert_own" on public.patient_medical_histories for insert to authenticated with check (patient_id = (select auth.uid()) and source = 'patient' and recorded_by is null);
drop policy if exists "patient_history_update_own" on public.patient_medical_histories;
create policy "patient_history_update_own" on public.patient_medical_histories for update to authenticated using (patient_id = (select auth.uid()) and source = 'patient') with check (patient_id = (select auth.uid()) and source = 'patient');
drop policy if exists "consultations_select_authorized" on public.consultations;
create policy "consultations_select_authorized" on public.consultations for select to authenticated using (patient_id = (select auth.uid()) or (doctor_id = (select auth.uid()) and exists (select 1 from public.clinic_memberships m where m.clinic_id = consultations.clinic_id and m.user_id = (select auth.uid()) and m.role = 'doctor')) or exists (select 1 from public.clinic_memberships m where m.clinic_id = consultations.clinic_id and m.user_id = (select auth.uid()) and m.role in ('clinic_admin','super_admin')));
drop policy if exists "prescriptions_select_authorized" on public.prescriptions;
create policy "prescriptions_select_authorized" on public.prescriptions for select to authenticated using (patient_id = (select auth.uid()) or (doctor_id = (select auth.uid()) and exists (select 1 from public.clinic_memberships m where m.clinic_id = prescriptions.clinic_id and m.user_id = (select auth.uid()) and m.role = 'doctor')) or exists (select 1 from public.clinic_memberships m where m.clinic_id = prescriptions.clinic_id and m.user_id = (select auth.uid()) and m.role in ('clinic_admin','super_admin')));
drop policy if exists "prescription_items_select_authorized" on public.prescription_items;
create policy "prescription_items_select_authorized" on public.prescription_items for select to authenticated using (exists (select 1 from public.prescriptions p where p.id = prescription_items.prescription_id and (p.patient_id = (select auth.uid()) or (p.doctor_id = (select auth.uid()) and exists (select 1 from public.clinic_memberships doctor_membership where doctor_membership.clinic_id = p.clinic_id and doctor_membership.user_id = (select auth.uid()) and doctor_membership.role = 'doctor')) or exists (select 1 from public.clinic_memberships m where m.clinic_id = p.clinic_id and m.user_id = (select auth.uid()) and m.role in ('clinic_admin','super_admin')))));

create or replace function public.save_patient_history(p_allergies text, p_conditions text, p_medications text, p_symptoms text, p_notes text)
returns public.patient_medical_histories language plpgsql security definer set search_path = '' as $$
declare v_row public.patient_medical_histories;
begin
  insert into public.patient_medical_histories(patient_id, allergies, conditions, medications, symptoms, notes, source)
  values (auth.uid(), p_allergies, p_conditions, p_medications, p_symptoms, p_notes, 'patient') returning * into v_row;
  return v_row;
end; $$;

create or replace function public.list_patient_medical_records(p_patient_id uuid default null)
returns table (history_id uuid, patient_id uuid, allergies text, conditions text, medications text, symptoms text, notes text, history_source text, history_created_at timestamptz, consultation_id uuid, consultation_status text, clinical_notes text, prescription_id uuid, prescription_status text)
language sql security definer set search_path = '' as $$
  select h.id, h.patient_id, h.allergies, h.conditions, h.medications, h.symptoms, h.notes, h.source, h.created_at,
    c.id, c.status, c.clinical_notes, pr.id, pr.status
  from public.patient_medical_histories h
  left join public.consultations c on c.patient_id = h.patient_id
  left join public.prescriptions pr on pr.consultation_id = c.id
  where h.patient_id = coalesce(p_patient_id, (select auth.uid()))
    and (h.patient_id = (select auth.uid()) or exists (select 1 from public.consultations authorized_consultation where authorized_consultation.id = c.id and ((authorized_consultation.doctor_id = (select auth.uid()) and exists (select 1 from public.clinic_memberships doctor_membership where doctor_membership.user_id = (select auth.uid()) and doctor_membership.clinic_id = authorized_consultation.clinic_id and doctor_membership.role = 'doctor')) or exists (select 1 from public.clinic_memberships m where m.user_id = (select auth.uid()) and m.clinic_id = authorized_consultation.clinic_id and m.role in ('clinic_admin','super_admin')))));

$$;

create or replace function public.create_consultation(p_patient_id uuid, p_clinic_id uuid, p_queue_entry_id uuid, p_symptoms text, p_clinical_notes text, p_diagnosis_notes text)
returns public.consultations language plpgsql security definer set search_path = '' as $$
declare v_row public.consultations;
begin
  if not exists (select 1 from public.clinic_memberships m where m.clinic_id=p_clinic_id and m.user_id=(select auth.uid()) and m.role='doctor') then raise exception 'doctor access required'; end if;
  if not exists (select 1 from public.queue_entries e join public.queue_sessions s on s.id = e.session_id where e.id = p_queue_entry_id and e.patient_id = p_patient_id and s.clinic_id = p_clinic_id and s.doctor_id = (select auth.uid())) then raise exception 'authorized queue entry required'; end if;
  insert into public.consultations(patient_id,doctor_id,clinic_id,queue_entry_id,symptoms,clinical_notes,diagnosis_notes)
  values(p_patient_id,auth.uid(),p_clinic_id,p_queue_entry_id,coalesce(p_symptoms,''),coalesce(p_clinical_notes,''),coalesce(p_diagnosis_notes,'')) returning * into v_row;
  return v_row;
end; $$;

create or replace function public.finalize_consultation(p_consultation_id uuid)
returns public.consultations language plpgsql security definer set search_path = '' as $$
declare v_row public.consultations;
begin
  update public.consultations set status='finalized', finalized_at=coalesce(finalized_at,now()), updated_at=now() where id=p_consultation_id and doctor_id=(select auth.uid()) and exists (select 1 from public.clinic_memberships m where m.clinic_id = consultations.clinic_id and m.user_id = (select auth.uid()) and m.role = 'doctor') returning * into v_row;
  if not found then raise exception 'consultation unavailable'; end if;
  return v_row;
end; $$;

create or replace function public.create_prescription(p_consultation_id uuid, p_items jsonb)
returns public.prescriptions language plpgsql security definer set search_path = '' as $$
declare v_consult public.consultations; v_row public.prescriptions; v_item jsonb;
begin
  select * into v_consult from public.consultations where id=p_consultation_id and doctor_id=(select auth.uid()) and status='finalized';
  if not found then raise exception 'finalized consultation required'; end if;
  if not exists (select 1 from public.clinic_memberships m where m.clinic_id = v_consult.clinic_id and m.user_id = (select auth.uid()) and m.role = 'doctor') then raise exception 'doctor access required'; end if;
  insert into public.prescriptions(consultation_id,patient_id,doctor_id,clinic_id) values(v_consult.id,v_consult.patient_id,(select auth.uid()),v_consult.clinic_id) returning * into v_row;
  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into public.prescription_items(prescription_id,medicine_name,strength,dose,frequency,duration,instructions)
    values(v_row.id,v_item->>'medicine_name',v_item->>'strength',v_item->>'dose',v_item->>'frequency',v_item->>'duration',coalesce(v_item->>'instructions',''));
  end loop;
  return v_row;
end; $$;

create or replace function public.finalize_prescription(p_prescription_id uuid)
returns public.prescriptions language plpgsql security definer set search_path = '' as $$
declare v_row public.prescriptions;
begin
  update public.prescriptions set status='finalized', finalized_at=coalesce(finalized_at,now()) where id=p_prescription_id and doctor_id=(select auth.uid()) and exists(select 1 from public.consultations c where c.id=prescriptions.consultation_id and c.status='finalized') and exists (select 1 from public.clinic_memberships m where m.clinic_id = prescriptions.clinic_id and m.user_id = (select auth.uid()) and m.role = 'doctor') returning * into v_row;
  if not found then raise exception 'prescription unavailable'; end if;
  return v_row;
end; $$;

revoke execute on function public.save_patient_history(text,text,text,text,text) from public;
grant execute on function public.save_patient_history(text,text,text,text,text) to authenticated;
revoke execute on function public.list_patient_medical_records(uuid) from public;
grant execute on function public.list_patient_medical_records(uuid) to authenticated;
revoke execute on function public.create_consultation(uuid,uuid,uuid,text,text,text) from public;
grant execute on function public.create_consultation(uuid,uuid,uuid,text,text,text) to authenticated;
revoke execute on function public.finalize_consultation(uuid) from public;
grant execute on function public.finalize_consultation(uuid) to authenticated;
revoke execute on function public.create_prescription(uuid,jsonb) from public;
grant execute on function public.create_prescription(uuid,jsonb) to authenticated;
revoke execute on function public.finalize_prescription(uuid) from public;
grant execute on function public.finalize_prescription(uuid) to authenticated;

insert into storage.buckets (id, name, public) values ('medical-documents','medical-documents',false) on conflict (id) do nothing;
drop policy if exists "medical_docs_patient_upload" on storage.objects;
create policy "medical_docs_patient_upload" on storage.objects for insert to authenticated with check (bucket_id = 'medical-documents' and (storage.foldername(name))[1] = (select auth.uid()::text));
drop policy if exists "medical_docs_authorized_read" on storage.objects;
create policy "medical_docs_authorized_read" on storage.objects for select to authenticated using (
  bucket_id = 'medical-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid()::text)
    or exists (
      select 1
      from public.medical_documents d
      join public.consultations c on c.patient_id = d.patient_id
      join public.clinic_memberships m on m.clinic_id = c.clinic_id
      where d.storage_path = name
        and m.user_id = (select auth.uid())
        and (
          (m.role = 'doctor' and c.doctor_id = (select auth.uid()))
          or m.role in ('clinic_admin', 'super_admin')
        )
    )
  )
);
