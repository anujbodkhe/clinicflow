-- ClinicFlow queue foundation
-- Additive migration. Apply through Supabase MCP only after review/approval.

do $$
begin
  create type public.queue_status as enum ('waiting', 'called', 'in_progress', 'completed', 'cancelled', 'no_show');
exception when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.registration_source as enum ('online', 'walk_in');
exception when duplicate_object then null;
end;
$$;

create table if not exists public.doctor_schedules (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete restrict,
  doctor_id uuid not null references public.profiles(id) on delete restrict,
  weekday smallint not null check (weekday between 0 and 6),
  starts_at time not null,
  ends_at time not null,
  consultation_minutes smallint not null default 10 check (consultation_minutes between 5 and 120),
  online_capacity integer not null default 20 check (online_capacity >= 0),
  walk_in_reserve integer not null default 5 check (walk_in_reserve >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.queue_sessions (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete restrict,
  doctor_id uuid not null references public.profiles(id) on delete restrict,
  schedule_id uuid references public.doctor_schedules(id) on delete restrict,
  session_date date not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  online_capacity integer not null check (online_capacity >= 0),
  walk_in_reserve integer not null check (walk_in_reserve >= 0),
  total_capacity integer generated always as (online_capacity + walk_in_reserve) stored,
  status text not null default 'open' check (status in ('open', 'closed', 'completed')),
  created_at timestamptz not null default now(),
  unique (doctor_id, session_date, starts_at)
);

create table if not exists public.queue_entries (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.queue_sessions(id) on delete restrict,
  patient_id uuid not null references public.profiles(id) on delete restrict,
  token integer not null,
  status public.queue_status not null default 'waiting',
  source public.registration_source not null,
  urgency text not null default 'standard' check (urgency in ('standard', 'urgent')),
  sos_requested_at timestamptz,
  sos_approved_at timestamptz,
  estimated_minutes integer not null default 10 check (estimated_minutes >= 0),
  created_at timestamptz not null default now(),
  called_at timestamptz,
  completed_at timestamptz,
  unique (session_id, token),
  unique (session_id, patient_id)
);

create index queue_sessions_clinic_date_idx on public.queue_sessions (clinic_id, session_date);
create index queue_entries_session_status_idx on public.queue_entries (session_id, status, created_at);
create index queue_entries_patient_idx on public.queue_entries (patient_id, created_at desc);

alter table public.doctor_schedules enable row level security;
alter table public.queue_sessions enable row level security;
alter table public.queue_entries enable row level security;

drop policy if exists "schedules_select_members" on public.doctor_schedules;
create policy "schedules_select_members" on public.doctor_schedules for select to authenticated
using (exists (select 1 from public.clinic_memberships m where m.clinic_id = doctor_schedules.clinic_id and m.user_id = (select auth.uid())));
drop policy if exists "sessions_select_members" on public.queue_sessions;
create policy "sessions_select_members" on public.queue_sessions for select to authenticated
using (exists (select 1 from public.clinic_memberships m where m.clinic_id = queue_sessions.clinic_id and m.user_id = (select auth.uid())));
drop policy if exists "entries_select_patient_or_staff" on public.queue_entries;
create policy "entries_select_patient_or_staff" on public.queue_entries for select to authenticated
using (patient_id = (select auth.uid()) or exists (select 1 from public.queue_sessions s join public.clinic_memberships m on m.clinic_id = s.clinic_id where s.id = queue_entries.session_id and m.user_id = (select auth.uid()) and m.role in ('super_admin','clinic_admin','doctor','receptionist')));

create or replace function public.register_for_queue(p_session_id uuid, p_urgency text default 'standard')
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare v_session public.queue_sessions; v_entry public.queue_entries; v_token integer;
begin
  if p_urgency not in ('standard','urgent') then raise exception 'invalid urgency'; end if;
  select * into v_session from public.queue_sessions where id = p_session_id and status = 'open' for update;
  if not found then raise exception 'session unavailable'; end if;
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'patient') then raise exception 'patient access required'; end if;
  if exists (select 1 from public.queue_entries where session_id = p_session_id and patient_id = auth.uid() and status not in ('cancelled','no_show','completed')) then raise exception 'already registered'; end if;
  if (select count(*) from public.queue_entries where session_id = p_session_id and source = 'online' and status not in ('cancelled','no_show')) >= v_session.online_capacity then raise exception 'online capacity reached'; end if;
  if (select count(*) from public.queue_entries where session_id = p_session_id and status not in ('cancelled','no_show')) >= v_session.total_capacity then raise exception 'capacity reached'; end if;
  select coalesce(max(token),0) + 1 into v_token from public.queue_entries where session_id = p_session_id;
  insert into public.queue_entries (session_id, patient_id, token, source, urgency, estimated_minutes)
  values (p_session_id, auth.uid(), v_token, 'online', p_urgency, case when p_urgency = 'urgent' then 15 else 10 end)
  returning * into v_entry;
  return v_entry;
end;
$$;

create or replace function public.create_walk_in(p_session_id uuid, p_patient_id uuid, p_urgency text default 'standard')
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare v_session public.queue_sessions; v_entry public.queue_entries; v_token integer; v_membership public.clinic_memberships;
begin
  if p_urgency not in ('standard','urgent') then raise exception 'invalid urgency'; end if;
  select * into v_session from public.queue_sessions where id = p_session_id and status = 'open' for update;
  if not found then raise exception 'session unavailable'; end if;
  select m.* into v_membership from public.clinic_memberships m where m.clinic_id = v_session.clinic_id and m.user_id = auth.uid() and m.role in ('super_admin','clinic_admin','receptionist');
  if not found then raise exception 'staff access required'; end if;
  if exists (select 1 from public.queue_entries where session_id = p_session_id and patient_id = p_patient_id and status not in ('cancelled','no_show','completed')) then raise exception 'already registered'; end if;
  if (select count(*) from public.queue_entries where session_id = p_session_id and source = 'walk_in' and status not in ('cancelled','no_show')) >= v_session.walk_in_reserve then raise exception 'walk-in capacity reached'; end if;
  if (select count(*) from public.queue_entries where session_id = p_session_id and status not in ('cancelled','no_show')) >= v_session.total_capacity then raise exception 'capacity reached'; end if;
  select coalesce(max(token),0) + 1 into v_token from public.queue_entries where session_id = p_session_id;
  insert into public.queue_entries (session_id, patient_id, token, source, urgency, estimated_minutes)
  values (p_session_id, p_patient_id, v_token, 'walk_in', p_urgency, case when p_urgency = 'urgent' then 15 else 10 end)
  returning * into v_entry;
  return v_entry;
end;
$$;

create or replace function public.request_queue_sos(p_entry_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare v_entry public.queue_entries;
begin
  update public.queue_entries
  set sos_requested_at = coalesce(sos_requested_at, now())
  where id = p_entry_id and patient_id = auth.uid() and status = 'waiting'
  returning * into v_entry;
  if not found then raise exception 'queue entry unavailable'; end if;
  return v_entry;
end;
$$;

create or replace function public.approve_queue_sos(p_entry_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare v_entry public.queue_entries;
begin
  if not exists (select 1 from public.queue_entries e join public.queue_sessions s on s.id = e.session_id join public.clinic_memberships m on m.clinic_id = s.clinic_id where e.id = p_entry_id and m.user_id = auth.uid() and m.role in ('super_admin','clinic_admin','doctor','receptionist')) then raise exception 'staff access required'; end if;
  update public.queue_entries set sos_approved_at = coalesce(sos_approved_at, now()), urgency = 'urgent', estimated_minutes = 15 where id = p_entry_id and sos_requested_at is not null and status = 'waiting' returning * into v_entry;
  if not found then raise exception 'SOS request unavailable'; end if;
  return v_entry;
end;
$$;

create or replace function public.update_queue_status(p_entry_id uuid, p_status public.queue_status)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare v_entry public.queue_entries;
begin
  if p_status not in ('called','in_progress','completed','cancelled','no_show') then raise exception 'invalid status'; end if;
  if not exists (
    select 1
    from public.queue_entries
    where id = p_entry_id
      and (
        (status = 'waiting' and p_status in ('called','cancelled','no_show'))
        or (status = 'called' and p_status in ('in_progress','cancelled','no_show'))
        or (status = 'in_progress' and p_status in ('completed','cancelled','no_show'))
      )
  ) then raise exception 'invalid status transition'; end if;
  if not exists (select 1 from public.queue_entries e join public.queue_sessions s on s.id = e.session_id join public.clinic_memberships m on m.clinic_id = s.clinic_id where e.id = p_entry_id and m.user_id = auth.uid() and m.role in ('super_admin','clinic_admin','doctor','receptionist')) then raise exception 'staff access required'; end if;
  update public.queue_entries set status = p_status, called_at = case when p_status = 'called' then coalesce(called_at, now()) else called_at end, completed_at = case when p_status = 'completed' then coalesce(completed_at, now()) else completed_at end where id = p_entry_id returning * into v_entry;
  if not found then raise exception 'queue entry unavailable'; end if;
  return v_entry;
end;
$$;

create or replace function public.patient_queue_availability(p_clinic_id uuid default null)
returns table (session_id uuid, clinic_id uuid, clinic_name text, doctor_id uuid, doctor_name text, session_date date, starts_at timestamptz, ends_at timestamptz, online_capacity integer, walk_in_reserve integer, total_capacity integer, registered_count bigint)
language sql
security definer
set search_path = ''
as $$
  select s.id, s.clinic_id, c.name, s.doctor_id, p.full_name, s.session_date, s.starts_at, s.ends_at, s.online_capacity, s.walk_in_reserve, s.total_capacity,
    (select count(*) from public.queue_entries e where e.session_id = s.id and e.status not in ('cancelled','no_show'))
  from public.queue_sessions s
  join public.clinics c on c.id = s.clinic_id
  join public.profiles p on p.id = s.doctor_id
  where s.status = 'open'
    and (p_clinic_id is null or s.clinic_id = p_clinic_id)
    and exists (select 1 from public.profiles me where me.id = (select auth.uid()) and me.role = 'patient');
$$;

create or replace function public.create_doctor_schedule(p_clinic_id uuid, p_doctor_id uuid, p_weekday smallint, p_starts_at time, p_ends_at time, p_consultation_minutes smallint default 10, p_online_capacity integer default 20, p_walk_in_reserve integer default 5)
returns public.doctor_schedules
language plpgsql security definer set search_path = ''
as $$
declare v_row public.doctor_schedules;
begin
  if not exists (select 1 from public.clinic_memberships m where m.clinic_id = p_clinic_id and m.user_id = (select auth.uid()) and m.role in ('super_admin','clinic_admin')) then raise exception 'administrator access required'; end if;
  if not exists (select 1 from public.clinic_memberships m where m.clinic_id = p_clinic_id and m.user_id = p_doctor_id and m.role = 'doctor') then raise exception 'doctor must belong to clinic'; end if;
  insert into public.doctor_schedules (clinic_id, doctor_id, weekday, starts_at, ends_at, consultation_minutes, online_capacity, walk_in_reserve) values (p_clinic_id,p_doctor_id,p_weekday,p_starts_at,p_ends_at,p_consultation_minutes,p_online_capacity,p_walk_in_reserve) returning * into v_row;
  return v_row;
end; $$;

create or replace function public.update_doctor_schedule(p_schedule_id uuid, p_weekday smallint, p_starts_at time, p_ends_at time, p_consultation_minutes smallint, p_online_capacity integer, p_walk_in_reserve integer, p_active boolean)
returns public.doctor_schedules
language plpgsql security definer set search_path = ''
as $$
declare v_row public.doctor_schedules; v_clinic_id uuid;
begin
  select clinic_id into v_clinic_id from public.doctor_schedules where id = p_schedule_id;
  if not exists (select 1 from public.clinic_memberships m where m.clinic_id = v_clinic_id and m.user_id = (select auth.uid()) and m.role in ('super_admin','clinic_admin')) then raise exception 'administrator access required'; end if;
  update public.doctor_schedules set weekday=p_weekday, starts_at=p_starts_at, ends_at=p_ends_at, consultation_minutes=p_consultation_minutes, online_capacity=p_online_capacity, walk_in_reserve=p_walk_in_reserve, active=p_active, updated_at=now() where id=p_schedule_id returning * into v_row;
  if not found then raise exception 'schedule unavailable'; end if; return v_row;
end; $$;

create or replace function public.create_queue_session(p_clinic_id uuid, p_doctor_id uuid, p_schedule_id uuid, p_session_date date, p_starts_at timestamptz, p_ends_at timestamptz, p_online_capacity integer, p_walk_in_reserve integer)
returns public.queue_sessions
language plpgsql security definer set search_path = ''
as $$
declare v_row public.queue_sessions;
begin
  if not exists (select 1 from public.clinic_memberships m where m.clinic_id=p_clinic_id and m.user_id=(select auth.uid()) and m.role in ('super_admin','clinic_admin')) then raise exception 'administrator access required'; end if;
  if not exists (select 1 from public.clinic_memberships m where m.clinic_id=p_clinic_id and m.user_id=p_doctor_id and m.role='doctor') then raise exception 'doctor must belong to clinic'; end if;
  if p_ends_at <= p_starts_at or p_online_capacity < 0 or p_walk_in_reserve < 0 then raise exception 'invalid session'; end if;
  insert into public.queue_sessions (clinic_id,doctor_id,schedule_id,session_date,starts_at,ends_at,online_capacity,walk_in_reserve) values (p_clinic_id,p_doctor_id,p_schedule_id,p_session_date,p_starts_at,p_ends_at,p_online_capacity,p_walk_in_reserve) returning * into v_row;
  return v_row;
end; $$;

create or replace function public.manage_queue_session(p_session_id uuid, p_status text, p_online_capacity integer, p_walk_in_reserve integer, p_starts_at timestamptz, p_ends_at timestamptz)
returns public.queue_sessions
language plpgsql security definer set search_path = ''
as $$
declare v_row public.queue_sessions; v_clinic_id uuid;
begin
  select clinic_id into v_clinic_id from public.queue_sessions where id=p_session_id;
  if not exists (select 1 from public.clinic_memberships m where m.clinic_id=v_clinic_id and m.user_id=(select auth.uid()) and m.role in ('super_admin','clinic_admin')) then raise exception 'administrator access required'; end if;
  if p_status not in ('open','closed','completed') or p_ends_at <= p_starts_at or p_online_capacity < 0 or p_walk_in_reserve < 0 then raise exception 'invalid session'; end if;
  update public.queue_sessions set status=p_status, online_capacity=p_online_capacity, walk_in_reserve=p_walk_in_reserve, starts_at=p_starts_at, ends_at=p_ends_at where id=p_session_id returning * into v_row;
  if not found then raise exception 'session unavailable'; end if; return v_row;
end; $$;

revoke execute on function public.patient_queue_availability(uuid) from public;
grant execute on function public.patient_queue_availability(uuid) to authenticated;
revoke execute on function public.create_doctor_schedule(uuid,uuid,smallint,time,time,smallint,integer,integer) from public;
grant execute on function public.create_doctor_schedule(uuid,uuid,smallint,time,time,smallint,integer,integer) to authenticated;
revoke execute on function public.update_doctor_schedule(uuid,smallint,time,time,smallint,integer,integer,boolean) from public;
grant execute on function public.update_doctor_schedule(uuid,smallint,time,time,smallint,integer,integer,boolean) to authenticated;
revoke execute on function public.create_queue_session(uuid,uuid,uuid,date,timestamptz,timestamptz,integer,integer) from public;
grant execute on function public.create_queue_session(uuid,uuid,uuid,date,timestamptz,timestamptz,integer,integer) to authenticated;
revoke execute on function public.manage_queue_session(uuid,text,integer,integer,timestamptz,timestamptz) from public;
grant execute on function public.manage_queue_session(uuid,text,integer,integer,timestamptz,timestamptz) to authenticated;

revoke execute on function public.register_for_queue(uuid, text) from public;
grant execute on function public.register_for_queue(uuid, text) to authenticated;
revoke execute on function public.create_walk_in(uuid, uuid, text) from public;
grant execute on function public.create_walk_in(uuid, uuid, text) to authenticated;
revoke execute on function public.request_queue_sos(uuid) from public;
grant execute on function public.request_queue_sos(uuid) to authenticated;
revoke execute on function public.approve_queue_sos(uuid) from public;
grant execute on function public.approve_queue_sos(uuid) to authenticated;
revoke execute on function public.update_queue_status(uuid, public.queue_status) from public;
grant execute on function public.update_queue_status(uuid, public.queue_status) to authenticated;
revoke insert, update, delete on public.queue_entries from authenticated;
revoke insert, update, delete on public.queue_sessions from authenticated;
revoke insert, update, delete on public.doctor_schedules from authenticated;
