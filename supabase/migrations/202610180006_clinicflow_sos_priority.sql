-- ClinicFlow SOS priority ordering and next-patient selection.
-- Preserve tokens and timestamps; prioritize only eligible waiting entries.

create or replace function public.call_next_queue_entry(p_session_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  if not exists (
    select 1
    from public.queue_sessions s
    join public.clinic_memberships m on m.clinic_id = s.clinic_id
    where s.id = p_session_id
      and s.status = 'open'
      and m.user_id = (select auth.uid())
      and m.role in ('super_admin', 'clinic_admin', 'doctor', 'receptionist')
  ) then raise exception 'staff access required'; end if;

  update public.queue_entries
  set status = 'called', called_at = coalesce(called_at, now())
  where id = (
    select e.id
    from public.queue_entries e
    where e.session_id = p_session_id
      and e.status = 'waiting'
    order by case when e.urgency = 'urgent' then 0 else 1 end,
      e.created_at asc,
      e.id asc
    for update skip locked
    limit 1
  )
  returning * into v_entry;

  if not found then raise exception 'no waiting queue entry'; end if;
  return v_entry;
end;
$$;

revoke execute on function public.call_next_queue_entry(uuid) from public;
grant execute on function public.call_next_queue_entry(uuid) to authenticated;
