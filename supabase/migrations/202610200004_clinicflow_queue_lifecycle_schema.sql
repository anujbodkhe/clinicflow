alter table public.queue_entries
  add column if not exists queue_order integer,
  add column if not exists missed_turn_count smallint not null default 0,
  add column if not exists call_grace_expires_at timestamptz,
  add column if not exists started_at timestamptz,
  add column if not exists standby_at timestamptz,
  add column if not exists sos_decision text,
  add column if not exists sos_priority_active boolean not null default false,
  add column if not exists sos_decided_by uuid references public.profiles(id) on delete restrict,
  add column if not exists sos_decided_at timestamptz;

update public.queue_entries
set queue_order = token
where queue_order is null;

update public.queue_entries
set call_grace_expires_at = called_at + interval '3 minutes'
where status = 'called' and called_at is not null;

update public.queue_entries
set started_at = coalesce(called_at, created_at)
where status = 'in_progress' and started_at is null;

alter table public.queue_entries
  alter column queue_order set not null,
  add constraint queue_entries_missed_turn_count_check check (missed_turn_count between 0 and 2),
  add constraint queue_entries_sos_decision_check check (sos_decision in ('pending', 'approved', 'rejected') or sos_decision is null);

update public.queue_entries
set sos_decision = case
  when sos_approved_at is not null then 'approved'
  when sos_requested_at is not null then 'pending'
  else null
end,
sos_priority_active = (sos_approved_at is not null),
urgency = case when sos_approved_at is not null then 'urgent' else 'standard' end,
estimated_minutes = case when sos_approved_at is not null then 15 else 10 end;

alter table public.queue_entries
  add constraint queue_entries_urgent_requires_approved_sos_check
    check (urgency <> 'urgent' or sos_decision is not distinct from 'approved');

alter table public.queue_entries
  drop constraint if exists queue_entries_session_id_patient_id_key;

create unique index if not exists queue_entries_one_active_registration_idx
  on public.queue_entries (session_id, patient_id)
  where patient_id is not null and status in ('waiting', 'called', 'in_progress', 'standby');

create index if not exists queue_entries_session_order_idx
  on public.queue_entries (session_id, queue_order, token);

create or replace function public.assign_queue_entry_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select coalesce(max(e.queue_order), 0) + 10
  into new.queue_order
  from public.queue_entries e
  where e.session_id = new.session_id;
  return new;
end;
$$;

drop trigger if exists assign_queue_entry_order_before_insert on public.queue_entries;
create trigger assign_queue_entry_order_before_insert
before insert on public.queue_entries
for each row execute function public.assign_queue_entry_order();

revoke all on function public.assign_queue_entry_order() from public, anon, authenticated;

create table if not exists public.queue_entry_events (
  id uuid primary key default gen_random_uuid(),
  queue_entry_id uuid not null references public.queue_entries(id) on delete restrict,
  session_id uuid not null references public.queue_sessions(id) on delete restrict,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  action text not null check (action in (
    'called', 'started', 'completed', 'cancelled', 'missed_first_call',
    'missed_second_call', 'standby_reactivated', 'sos_requested',
    'sos_approved', 'sos_rejected'
  )),
  from_status public.queue_status,
  to_status public.queue_status,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists queue_entry_events_entry_created_idx
  on public.queue_entry_events (queue_entry_id, created_at);

alter table public.queue_entry_events enable row level security;

drop policy if exists "queue_entry_events_select_clinic_staff" on public.queue_entry_events;
create policy "queue_entry_events_select_clinic_staff"
on public.queue_entry_events
for select to authenticated
using (
  exists (
    select 1
    from public.queue_sessions s
    join public.clinic_memberships m on m.clinic_id = s.clinic_id
    where s.id = queue_entry_events.session_id
      and m.user_id = (select auth.uid())
      and m.role in ('super_admin', 'clinic_admin', 'doctor', 'receptionist')
  )
);

revoke all on public.queue_entry_events from anon, authenticated;
grant select on public.queue_entry_events to authenticated;

drop policy if exists "profiles_select_queue_patient_names" on public.profiles;
create policy "profiles_select_queue_patient_names"
on public.profiles
for select to authenticated
using (
  exists (
    select 1
    from public.queue_entries e
    join public.queue_sessions s on s.id = e.session_id
    join public.clinic_memberships m on m.clinic_id = s.clinic_id
    where e.patient_id = profiles.id
      and m.user_id = (select auth.uid())
      and m.role in ('super_admin', 'clinic_admin', 'doctor', 'receptionist')
  )
);

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'queue_entries'
    ) then
      alter publication supabase_realtime add table public.queue_entries;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'queue_sessions'
    ) then
      alter publication supabase_realtime add table public.queue_sessions;
    end if;
  end if;
end;
$$;
