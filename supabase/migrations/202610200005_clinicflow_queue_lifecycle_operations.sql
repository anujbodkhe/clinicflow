drop function if exists public.list_clinic_walk_ins(uuid);

create function public.list_clinic_walk_ins(p_clinic_id uuid)
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
  created_at timestamptz,
  queue_order integer,
  missed_turn_count smallint,
  call_grace_expires_at timestamptz,
  started_at timestamptz,
  sos_decision text,
  sos_priority_active boolean,
  sos_decided_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select e.id, e.session_id, e.patient_id, e.walk_in_patient_id,
    e.token, e.status, e.source, e.urgency, e.estimated_minutes,
    e.sos_requested_at, e.sos_approved_at,
    w.full_name, w.phone, w.symptoms, e.created_at,
    e.queue_order, e.missed_turn_count, e.call_grace_expires_at,
    e.started_at, e.sos_decision, e.sos_priority_active, e.sos_decided_at
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
  order by e.queue_order, e.token;
$$;

revoke execute on function public.list_clinic_walk_ins(uuid) from public;
grant execute on function public.list_clinic_walk_ins(uuid) to authenticated;

create or replace function public.request_queue_sos(p_entry_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  select e.* into v_entry
  from public.queue_entries e
  where e.id = p_entry_id
    and e.patient_id = (select auth.uid())
    and e.status = 'waiting'
  for update;

  if not found then raise exception 'queue entry unavailable'; end if;

  if v_entry.sos_decision is not null then
    raise exception 'SOS request has already been reviewed';
  end if;

  if v_entry.sos_requested_at is null then
    update public.queue_entries
    set sos_requested_at = now(),
        sos_decision = 'pending'
    where id = p_entry_id
    returning * into v_entry;

    insert into public.queue_entry_events (
      queue_entry_id, session_id, actor_id, action, from_status, to_status
    )
    values (
      v_entry.id, v_entry.session_id, (select auth.uid()), 'sos_requested',
      v_entry.status, v_entry.status
    );
  end if;

  return v_entry;
end;
$$;

create or replace function public.approve_queue_sos(p_entry_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  select e.* into v_entry
  from public.queue_entries e
  join public.queue_sessions s on s.id = e.session_id
  join public.clinic_memberships m on m.clinic_id = s.clinic_id
  where e.id = p_entry_id
    and m.user_id = (select auth.uid())
    and m.role in ('super_admin', 'clinic_admin', 'receptionist')
  for update of e;

  if not found then raise exception 'staff access required'; end if;
  if v_entry.status not in ('waiting', 'standby') or v_entry.sos_decision is distinct from 'pending' then
    raise exception 'pending SOS request unavailable';
  end if;

  update public.queue_entries
  set sos_decision = 'approved',
      sos_decided_by = (select auth.uid()),
      sos_decided_at = now(),
      sos_approved_at = now(),
      sos_priority_active = true,
      urgency = 'urgent',
      estimated_minutes = 15
  where id = p_entry_id
  returning * into v_entry;

  insert into public.queue_entry_events (
    queue_entry_id, session_id, actor_id, action, from_status, to_status
  )
  values (
    v_entry.id, v_entry.session_id, (select auth.uid()), 'sos_approved',
    v_entry.status, v_entry.status
  );

  return v_entry;
end;
$$;

create or replace function public.reject_queue_sos(p_entry_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  select e.* into v_entry
  from public.queue_entries e
  join public.queue_sessions s on s.id = e.session_id
  join public.clinic_memberships m on m.clinic_id = s.clinic_id
  where e.id = p_entry_id
    and m.user_id = (select auth.uid())
    and m.role in ('super_admin', 'clinic_admin', 'receptionist')
  for update of e;

  if not found then raise exception 'staff access required'; end if;
  if v_entry.status not in ('waiting', 'standby') or v_entry.sos_decision is distinct from 'pending' then
    raise exception 'pending SOS request unavailable';
  end if;

  update public.queue_entries
  set sos_decision = 'rejected',
      sos_decided_by = (select auth.uid()),
      sos_decided_at = now(),
      sos_priority_active = false,
      urgency = 'standard',
      estimated_minutes = 10
  where id = p_entry_id
  returning * into v_entry;

  insert into public.queue_entry_events (
    queue_entry_id, session_id, actor_id, action, from_status, to_status
  )
  values (
    v_entry.id, v_entry.session_id, (select auth.uid()), 'sos_rejected',
    v_entry.status, v_entry.status
  );

  return v_entry;
end;
$$;

create or replace function public.call_next_queue_entry(p_session_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  perform 1
  from public.queue_sessions s
  join public.clinic_memberships m on m.clinic_id = s.clinic_id
  where s.id = p_session_id
    and s.status = 'open'
    and m.user_id = (select auth.uid())
    and m.role in ('super_admin', 'clinic_admin', 'doctor', 'receptionist')
  for update of s;

  if not found then raise exception 'staff access required'; end if;
  if exists (
    select 1 from public.queue_entries e
    where e.session_id = p_session_id
      and e.status in ('called', 'in_progress')
  ) then
    raise exception 'finish the active queue entry before calling another patient';
  end if;

  select e.* into v_entry
  from public.queue_entries e
  where e.session_id = p_session_id
    and e.status = 'waiting'
  order by
    case when e.sos_priority_active then 0 else 1 end,
    case when e.sos_priority_active then e.sos_decided_at end nulls last,
    e.queue_order,
    e.token,
    e.id
  for update
  limit 1;

  if not found then raise exception 'no waiting queue entry'; end if;

  update public.queue_entries
  set status = 'called',
      called_at = now(),
      call_grace_expires_at = now() + interval '3 minutes',
      started_at = null
  where id = v_entry.id
  returning * into v_entry;

  insert into public.queue_entry_events (
    queue_entry_id, session_id, actor_id, action, from_status, to_status
  )
  values (
    v_entry.id, v_entry.session_id, (select auth.uid()), 'called',
    'waiting', 'called'
  );

  return v_entry;
end;
$$;

create or replace function public.update_queue_status(
  p_entry_id uuid,
  p_status public.queue_status
)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
  v_action text;
  v_previous_status public.queue_status;
begin
  select e.* into v_entry
  from public.queue_entries e
  join public.queue_sessions s on s.id = e.session_id
  join public.clinic_memberships m on m.clinic_id = s.clinic_id
  where e.id = p_entry_id
    and m.user_id = (select auth.uid())
    and m.role in ('super_admin', 'clinic_admin', 'doctor', 'receptionist')
  for update of e;

  if not found then raise exception 'staff access required'; end if;
  if p_status not in ('called', 'in_progress', 'completed', 'cancelled') then
    raise exception 'use the missed-turn operation for no-show handling';
  end if;

  if not (
    (v_entry.status = 'waiting' and p_status = 'cancelled')
    or (v_entry.status = 'called' and p_status in ('in_progress', 'cancelled'))
    or (v_entry.status = 'in_progress' and p_status in ('completed', 'cancelled'))
  ) then
    raise exception 'invalid status transition';
  end if;

  v_previous_status := v_entry.status;

  update public.queue_entries
  set status = p_status,
      started_at = case when p_status = 'in_progress' then now() else started_at end,
      completed_at = case when p_status = 'completed' then now() else completed_at end,
      call_grace_expires_at = null
  where id = p_entry_id
  returning * into v_entry;

  v_action := case p_status
    when 'in_progress' then 'started'
    when 'completed' then 'completed'
    else 'cancelled'
  end;

  insert into public.queue_entry_events (
    queue_entry_id, session_id, actor_id, action, from_status, to_status
  )
  values (
    v_entry.id, v_entry.session_id, (select auth.uid()), v_action,
    v_previous_status,
    p_status
  );

  return v_entry;
end;
$$;

create or replace function public.process_missed_turn(p_entry_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
  v_waiting_count integer;
  v_insert_position integer;
  v_next_status public.queue_status;
  v_action text;
begin
  select e.* into v_entry
  from public.queue_entries e
  join public.queue_sessions s on s.id = e.session_id
  join public.clinic_memberships m on m.clinic_id = s.clinic_id
  where e.id = p_entry_id
    and m.user_id = (select auth.uid())
    and m.role in ('super_admin', 'clinic_admin', 'receptionist')
  for update of s, e;

  if not found then raise exception 'receptionist access required'; end if;
  if v_entry.status <> 'called' then raise exception 'queue entry is not awaiting a call'; end if;
  if v_entry.call_grace_expires_at is null and v_entry.called_at is null then
    raise exception 'call grace expiry is unavailable';
  end if;
  if coalesce(v_entry.call_grace_expires_at, v_entry.called_at + interval '3 minutes') > now() then
    raise exception 'the three-minute grace period has not elapsed';
  end if;

  if v_entry.missed_turn_count < 1 then
    select count(*)::integer into v_waiting_count
    from public.queue_entries e
    where e.session_id = v_entry.session_id
      and e.status = 'waiting';

    v_insert_position := least(3, v_waiting_count + 1);

    with ranked as (
      select e.id,
        (row_number() over (order by e.queue_order, e.token, e.id) * 10)::integer as next_order
      from public.queue_entries e
      where e.session_id = v_entry.session_id
        and e.status = 'waiting'
    )
    update public.queue_entries e
    set queue_order = ranked.next_order
    from ranked
    where e.id = ranked.id;

    update public.queue_entries
    set queue_order = queue_order + 10
    where session_id = v_entry.session_id
      and status = 'waiting'
      and queue_order >= v_insert_position * 10;

    v_next_status := 'waiting';
    v_action := 'missed_first_call';

    update public.queue_entries
    set status = v_next_status,
        missed_turn_count = 1,
        sos_priority_active = false,
        call_grace_expires_at = null,
        queue_order = v_insert_position * 10
    where id = p_entry_id
    returning * into v_entry;
  else
    v_next_status := 'standby';
    v_action := 'missed_second_call';

    update public.queue_entries
    set status = v_next_status,
        missed_turn_count = least(missed_turn_count + 1, 2),
        standby_at = now(),
        call_grace_expires_at = null
    where id = p_entry_id
    returning * into v_entry;
  end if;

  insert into public.queue_entry_events (
    queue_entry_id, session_id, actor_id, action, from_status, to_status, details
  )
  values (
    v_entry.id, v_entry.session_id, (select auth.uid()), v_action,
    'called', v_next_status,
    jsonb_build_object('grace_period_minutes', 3, 'push_back_positions',
      case when v_next_status = 'waiting' then least(2, v_waiting_count) else 0 end)
  );

  return v_entry;
end;
$$;

create or replace function public.reactivate_standby_queue_entry(p_entry_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  select e.* into v_entry
  from public.queue_entries e
  join public.queue_sessions s on s.id = e.session_id
  join public.clinic_memberships m on m.clinic_id = s.clinic_id
  where e.id = p_entry_id
    and m.user_id = (select auth.uid())
    and m.role in ('super_admin', 'clinic_admin', 'receptionist')
  for update of s, e;

  if not found then raise exception 'receptionist access required'; end if;
  if v_entry.status <> 'standby' then raise exception 'queue entry is not in standby'; end if;

  update public.queue_entries
  set status = 'waiting',
      queue_order = coalesce((
        select max(e.queue_order) + 10
        from public.queue_entries e
        where e.session_id = v_entry.session_id
      ), 10),
      standby_at = null,
      call_grace_expires_at = null
  where id = p_entry_id
  returning * into v_entry;

  insert into public.queue_entry_events (
    queue_entry_id, session_id, actor_id, action, from_status, to_status
  )
  values (
    v_entry.id, v_entry.session_id, (select auth.uid()), 'standby_reactivated',
    'standby', 'waiting'
  );

  return v_entry;
end;
$$;

create or replace function public.patient_queue_position(p_entry_id uuid)
returns table (queue_position integer, estimated_wait_minutes integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.queue_entries e
    join public.profiles p on p.id = e.patient_id
    where e.id = p_entry_id
      and e.patient_id = (select auth.uid())
      and p.role = 'patient'
  ) then
    raise exception 'patient queue entry unavailable';
  end if;

  return query
  with ordered as (
    select e.id,
      e.status,
      row_number() over (
        order by
          case when e.status in ('called', 'in_progress') then 0
               when e.sos_priority_active then 1 else 2 end,
          case when e.sos_priority_active then e.sos_decided_at end nulls last,
          e.queue_order,
          e.token,
          e.id
      )::integer as position,
      case
        when e.status = 'in_progress' then greatest(
          0,
          e.estimated_minutes - floor(
            extract(epoch from (now() - coalesce(e.started_at, e.called_at, e.created_at))) / 60
          )::integer
        )
        else e.estimated_minutes
      end::integer as remaining_minutes
    from public.queue_entries e
    join public.queue_entries target on target.session_id = e.session_id
    where target.id = p_entry_id
      and e.status in ('waiting', 'called', 'in_progress')
  ),
  estimates as (
    select o.*,
      coalesce(
        sum(o.remaining_minutes) over (
          order by o.position
          rows between unbounded preceding and 1 preceding
        ),
        0
      )::integer as wait_minutes
    from ordered o
  )
  select estimates.position, estimates.wait_minutes
  from estimates
  where estimates.id = p_entry_id;
end;
$$;

revoke execute on function public.request_queue_sos(uuid) from public;
grant execute on function public.request_queue_sos(uuid) to authenticated;
revoke execute on function public.approve_queue_sos(uuid) from public;
grant execute on function public.approve_queue_sos(uuid) to authenticated;
revoke execute on function public.reject_queue_sos(uuid) from public;
grant execute on function public.reject_queue_sos(uuid) to authenticated;
revoke execute on function public.call_next_queue_entry(uuid) from public;
grant execute on function public.call_next_queue_entry(uuid) to authenticated;
revoke execute on function public.update_queue_status(uuid, public.queue_status) from public;
grant execute on function public.update_queue_status(uuid, public.queue_status) to authenticated;
revoke execute on function public.process_missed_turn(uuid) from public;
grant execute on function public.process_missed_turn(uuid) to authenticated;
revoke execute on function public.reactivate_standby_queue_entry(uuid) from public;
grant execute on function public.reactivate_standby_queue_entry(uuid) to authenticated;
revoke execute on function public.patient_queue_position(uuid) from public;
grant execute on function public.patient_queue_position(uuid) to authenticated;
