-- ClinicFlow compulsory symptoms registration.
-- Atomically persists required symptoms and creates the queue entry.

revoke execute on function public.register_for_queue(uuid, text) from authenticated;
revoke execute on function public.create_walk_in(uuid, uuid, text) from authenticated;

drop function if exists public.register_for_queue_with_symptoms(uuid, text, text);
create function public.register_for_queue_with_symptoms(p_session_id uuid, p_urgency text, p_symptoms text)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.queue_sessions;
  v_entry public.queue_entries;
  v_token integer;
  v_symptoms text := btrim(coalesce(p_symptoms, ''));
begin
  if v_symptoms = '' then raise exception 'symptoms are required'; end if;
  if p_urgency is distinct from 'standard' then raise exception 'urgency requires an approved SOS review'; end if;
  select * into v_session from public.queue_sessions where id = p_session_id and status = 'open' for update;
  if not found then raise exception 'session unavailable'; end if;
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'patient') then raise exception 'patient access required'; end if;
  if exists (select 1 from public.queue_entries where session_id = p_session_id and patient_id = auth.uid() and status not in ('cancelled','no_show','completed')) then raise exception 'already registered'; end if;
  if (select count(*) from public.queue_entries where session_id = p_session_id and source = 'online' and status not in ('cancelled','no_show')) >= v_session.online_capacity then raise exception 'online capacity reached'; end if;
  if (select count(*) from public.queue_entries where session_id = p_session_id and status not in ('cancelled','no_show')) >= v_session.total_capacity then raise exception 'capacity reached'; end if;
  insert into public.patient_medical_histories(patient_id, symptoms, source)
  values (auth.uid(), v_symptoms, 'patient');
  select coalesce(max(token),0) + 1 into v_token from public.queue_entries where session_id = p_session_id;
  insert into public.queue_entries (session_id, patient_id, token, source, urgency, estimated_minutes)
  values (p_session_id, auth.uid(), v_token, 'online', 'standard', 10)
  returning * into v_entry;
  return v_entry;
end;
$$;

drop function if exists public.create_walk_in_with_symptoms(uuid, uuid, text, text);
create function public.create_walk_in_with_symptoms(p_session_id uuid, p_patient_id uuid, p_urgency text, p_symptoms text)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.queue_sessions;
  v_entry public.queue_entries;
  v_token integer;
  v_membership public.clinic_memberships;
  v_symptoms text := btrim(coalesce(p_symptoms, ''));
begin
  if v_symptoms = '' then raise exception 'symptoms are required'; end if;
  if p_urgency is distinct from 'standard' then raise exception 'urgency requires an approved SOS review'; end if;
  select * into v_session from public.queue_sessions where id = p_session_id and status = 'open' for update;
  if not found then raise exception 'session unavailable'; end if;
  select m.* into v_membership from public.clinic_memberships m where m.clinic_id = v_session.clinic_id and m.user_id = auth.uid() and m.role in ('super_admin','clinic_admin','receptionist');
  if not found then raise exception 'staff access required'; end if;
  if not exists (select 1 from public.profiles p where p.id = p_patient_id and p.role = 'patient') then raise exception 'patient profile required'; end if;
  if exists (select 1 from public.queue_entries where session_id = p_session_id and patient_id = p_patient_id and status not in ('cancelled','no_show','completed')) then raise exception 'already registered'; end if;
  if (select count(*) from public.queue_entries where session_id = p_session_id and source = 'walk_in' and status not in ('cancelled','no_show')) >= v_session.walk_in_reserve then raise exception 'walk-in capacity reached'; end if;
  if (select count(*) from public.queue_entries where session_id = p_session_id and status not in ('cancelled','no_show')) >= v_session.total_capacity then raise exception 'capacity reached'; end if;
  insert into public.patient_medical_histories(patient_id, symptoms, source)
  values (p_patient_id, v_symptoms, 'patient');
  select coalesce(max(token),0) + 1 into v_token from public.queue_entries where session_id = p_session_id;
  insert into public.queue_entries (session_id, patient_id, token, source, urgency, estimated_minutes)
  values (p_session_id, p_patient_id, v_token, 'walk_in', 'standard', 10)
  returning * into v_entry;
  return v_entry;
end;
$$;

revoke execute on function public.register_for_queue_with_symptoms(uuid, text, text) from public;
grant execute on function public.register_for_queue_with_symptoms(uuid, text, text) to authenticated;
revoke execute on function public.create_walk_in_with_symptoms(uuid, uuid, text, text) from public;
grant execute on function public.create_walk_in_with_symptoms(uuid, uuid, text, text) to authenticated;
