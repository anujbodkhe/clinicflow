-- ClinicFlow: Super Admin user listing and role management.
-- Role changes are serialized so concurrent requests cannot demote the last
-- Super Admin. Clinic-role assignments replace the user's previous clinic scope.

create or replace function public.admin_list_users()
returns table (
  user_id uuid,
  email text,
  full_name text,
  role text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles actor
    where actor.id = (select auth.uid())
      and actor.role = 'super_admin'
  ) then
    raise exception 'super-admin access required';
  end if;

  return query
  select auth_user.id, auth_user.email, profile.full_name, profile.role, profile.created_at
  from auth.users auth_user
  join public.profiles profile on profile.id = auth_user.id
  order by lower(coalesce(auth_user.email, '')), auth_user.created_at;
end;
$$;

revoke all on function public.admin_list_users() from public, anon;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.admin_change_user_role(
  p_target_user_id uuid,
  p_role text,
  p_clinic_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_actor_role text;
  v_current_role text;
  v_super_admin_count integer;
begin
  if v_actor_id is null then
    raise exception 'authentication required';
  end if;

  perform pg_advisory_xact_lock(438721, 1);

  select profile.role
  into v_actor_role
  from public.profiles profile
  where profile.id = v_actor_id;

  if v_actor_role is distinct from 'super_admin' then
    raise exception 'super-admin access required';
  end if;

  if p_target_user_id is null or p_target_user_id = v_actor_id then
    raise exception 'a different target user is required';
  end if;

  if p_role is null
     or p_role not in ('super_admin', 'clinic_admin', 'doctor', 'receptionist', 'patient') then
    raise exception 'invalid role';
  end if;

  select profile.role
  into v_current_role
  from public.profiles profile
  where profile.id = p_target_user_id
  for update;

  if not found then
    raise exception 'target user does not exist';
  end if;

  if v_current_role = 'super_admin' and p_role <> 'super_admin' then
    select count(*)::integer
    into v_super_admin_count
    from public.profiles profile
    where profile.role = 'super_admin';

    if v_super_admin_count <= 1 then
      raise exception 'the last Super Admin cannot be demoted';
    end if;
  end if;

  if p_role = 'patient' then
    if p_clinic_id is not null then
      raise exception 'patient role does not accept a clinic';
    end if;

    update public.profiles
    set role = 'patient', updated_at = now()
    where id = p_target_user_id;

    delete from public.clinic_memberships
    where user_id = p_target_user_id;
    return;
  end if;

  if p_role = 'super_admin' then
    if p_clinic_id is not null then
      raise exception 'Super Admin role does not accept a clinic';
    end if;

    update public.profiles
    set role = 'super_admin', updated_at = now()
    where id = p_target_user_id;

    delete from public.clinic_memberships
    where user_id = p_target_user_id;

    insert into public.clinic_memberships (clinic_id, user_id, role)
    select clinic.id, p_target_user_id, 'super_admin'
    from public.clinics clinic
    on conflict (clinic_id, user_id) do update
      set role = excluded.role;
    return;
  end if;

  if p_clinic_id is null or not exists (
    select 1
    from public.clinics clinic
    where clinic.id = p_clinic_id
      and clinic.active
  ) then
    raise exception 'an active clinic is required for this role';
  end if;

  update public.profiles
  set role = p_role, updated_at = now()
  where id = p_target_user_id;

  delete from public.clinic_memberships
  where user_id = p_target_user_id;

  insert into public.clinic_memberships (clinic_id, user_id, role)
  values (p_clinic_id, p_target_user_id, p_role);
end;
$$;

revoke all on function public.admin_change_user_role(uuid, text, uuid) from public, anon;
grant execute on function public.admin_change_user_role(uuid, text, uuid) to authenticated;

create or replace function public.add_super_admin_membership_for_clinic()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(438721, 1);

  insert into public.clinic_memberships (clinic_id, user_id, role)
  select new.id, profile.id, 'super_admin'
  from public.profiles profile
  where profile.role = 'super_admin'
  on conflict (clinic_id, user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists clinics_add_super_admin_memberships on public.clinics;
create trigger clinics_add_super_admin_memberships
after insert on public.clinics
for each row execute function public.add_super_admin_membership_for_clinic();

revoke all on function public.add_super_admin_membership_for_clinic() from public, anon, authenticated;

insert into public.clinic_memberships (clinic_id, user_id, role)
select clinic.id, profile.id, 'super_admin'
from public.clinics clinic
cross join public.profiles profile
where profile.role = 'super_admin'
on conflict (clinic_id, user_id) do update
  set role = excluded.role;
