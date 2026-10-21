-- ClinicFlow: isolated unauthenticated walk-in identity support.
-- Existing authenticated patient rows remain unchanged.

create table if not exists public.walk_in_patients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (char_length(trim(full_name)) between 2 and 160),
  phone text not null check (char_length(trim(phone)) between 3 and 40),
  symptoms text not null default '',
  created_at timestamptz not null default now()
);

alter table public.queue_entries
  add column if not exists walk_in_patient_id uuid
  references public.walk_in_patients(id) on delete restrict;

alter table public.consultations
  add column if not exists walk_in_patient_id uuid
  references public.walk_in_patients(id) on delete restrict;

alter table public.queue_entries alter column patient_id drop not null;
alter table public.consultations alter column patient_id drop not null;

alter table public.queue_entries
  drop constraint if exists queue_entries_patient_identity_check;
alter table public.queue_entries
  add constraint queue_entries_patient_identity_check
  check ((patient_id is not null) <> (walk_in_patient_id is not null));

alter table public.consultations
  drop constraint if exists consultations_patient_identity_check;
alter table public.consultations
  add constraint consultations_patient_identity_check
  check ((patient_id is not null) <> (walk_in_patient_id is not null));

alter table public.walk_in_patients enable row level security;
revoke all on public.walk_in_patients from anon, authenticated;

create or replace function public.list_clinic_walk_ins(p_clinic_id uuid)
returns table (
  id uuid,
  session_id uuid,
  patient_id uuid,
  walk_in_patient_id uuid,
  token integer,
  status public.queue_status,
  source public.registration_source,
  urgency text,
  estimated_minutes integer,
  sos_requested_at timestamptz,
  sos_approved_at timestamptz,
  full_name text,
  phone text,
  symptoms text,
  created_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select e.id, e.session_id, e.patient_id, e.walk_in_patient_id,
    e.token, e.status, e.source, e.urgency, e.estimated_minutes,
    e.sos_requested_at, e.sos_approved_at,
    w.full_name, w.phone, w.symptoms, e.created_at
  from public.queue_entries e
  join public.queue_sessions s on s.id = e.session_id
  join public.walk_in_patients w on w.id = e.walk_in_patient_id
  where s.clinic_id = p_clinic_id
    and exists (
      select 1 from public.clinic_memberships m
      where m.clinic_id = s.clinic_id
        and m.user_id = (select auth.uid())
        and m.role in ('super_admin', 'clinic_admin', 'doctor', 'receptionist')
    )
  order by e.created_at asc;
$$;

revoke execute on function public.list_clinic_walk_ins(uuid) from public;
grant execute on function public.list_clinic_walk_ins(uuid) to authenticated;

create or replace function public.create_walk_in(
  p_session_id uuid,
  p_full_name text,
  p_phone text,
  p_symptoms text default '',
  p_urgency text default 'standard'
) returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.queue_sessions;
  v_walk_in public.walk_in_patients;
  v_entry public.queue_entries;
  v_user uuid := (select auth.uid());
  v_token integer;
begin
  if p_urgency is distinct from 'standard' then
    raise exception 'urgency requires an approved SOS review';
  end if;

  if char_length(trim(coalesce(p_full_name, ''))) not between 2 and 160
     or char_length(trim(coalesce(p_phone, ''))) not between 3 and 40 then
    raise exception 'valid patient name and phone required';
  end if;

  select * into v_session
  from public.queue_sessions
  where id = p_session_id
    and status = 'open'
  for update;

  if not found then
    raise exception 'open queue session required';
  end if;

  if not exists (
    select 1
    from public.clinic_memberships m
    where m.clinic_id = v_session.clinic_id
      and m.user_id = v_user
      and m.role in ('clinic_admin', 'receptionist', 'super_admin')
  ) then
    raise exception 'staff access required';
  end if;

  if (
    select count(*)
    from public.queue_entries e
    where e.session_id = p_session_id
      and e.source = 'walk_in'::public.registration_source
      and e.status not in ('cancelled', 'no_show')
  ) >= v_session.walk_in_reserve then
    raise exception 'walk-in capacity reached';
  end if;

  if (
    select count(*)
    from public.queue_entries e
    where e.session_id = p_session_id
      and e.status not in ('cancelled', 'no_show')
  ) >= v_session.total_capacity then
    raise exception 'queue capacity reached';
  end if;

  select coalesce(max(e.token), 0) + 1
  into v_token
  from public.queue_entries e
  where e.session_id = p_session_id;

  insert into public.walk_in_patients(full_name, phone, symptoms)
  values (trim(p_full_name), trim(p_phone), coalesce(trim(p_symptoms), ''))
  returning * into v_walk_in;

  insert into public.queue_entries(
    session_id,
    patient_id,
    walk_in_patient_id,
    token,
    source,
    urgency,
    estimated_minutes
  ) values (
    p_session_id,
    null,
    v_walk_in.id,
    v_token,
    'walk_in'::public.registration_source,
    'standard',
    10
  )
  returning * into v_entry;

  return v_entry;
end;
$$;

create or replace function public.create_consultation(
  p_patient_id uuid,
  p_clinic_id uuid,
  p_queue_entry_id uuid,
  p_symptoms text,
  p_clinical_notes text,
  p_diagnosis_notes text
) returns public.consultations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
  v_row public.consultations;
begin
  if not exists (
    select 1
    from public.clinic_memberships m
    where m.clinic_id = p_clinic_id
      and m.user_id = (select auth.uid())
      and m.role = 'doctor'
  ) then
    raise exception 'doctor access required';
  end if;

  select e.* into v_entry
  from public.queue_entries e
  join public.queue_sessions s on s.id = e.session_id
  where e.id = p_queue_entry_id
    and s.clinic_id = p_clinic_id
    and s.doctor_id = (select auth.uid())
    and (
      (e.patient_id is not null and e.patient_id = p_patient_id)
      or (e.walk_in_patient_id is not null and p_patient_id is null)
    );

  if not found then
    raise exception 'authorized queue entry required';
  end if;

  insert into public.consultations(
    patient_id,
    walk_in_patient_id,
    doctor_id,
    clinic_id,
    queue_entry_id,
    symptoms,
    clinical_notes,
    diagnosis_notes
  ) values (
    v_entry.patient_id,
    v_entry.walk_in_patient_id,
    (select auth.uid()),
    p_clinic_id,
    p_queue_entry_id,
    coalesce(p_symptoms, ''),
    coalesce(p_clinical_notes, ''),
    coalesce(p_diagnosis_notes, '')
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke execute on function public.create_walk_in(uuid, text, text, text, text) from public;
grant execute on function public.create_walk_in(uuid, text, text, text, text) to authenticated;

revoke execute on function public.create_consultation(uuid, uuid, uuid, text, text, text) from public;
grant execute on function public.create_consultation(uuid, uuid, uuid, text, text, text) to authenticated;
