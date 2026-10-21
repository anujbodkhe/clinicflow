-- ClinicFlow identity and tenant foundation.
-- This must precede the queue/workflow migrations. Authenticated users cannot
-- assign themselves staff roles; initial super-admin promotion is operator-only.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'patient'
    check (role in ('super_admin', 'clinic_admin', 'doctor', 'receptionist', 'patient')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clinics (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 160),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  address text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clinic_memberships (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('super_admin', 'clinic_admin', 'doctor', 'receptionist')),
  created_at timestamptz not null default now(),
  unique (clinic_id, user_id)
);

create index if not exists clinic_memberships_user_role_idx
  on public.clinic_memberships (user_id, role, clinic_id);

create or replace function public.handle_new_clinicflow_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    left(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), 160),
    'patient'
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_clinicflow on auth.users;
create trigger on_auth_user_created_clinicflow
  after insert on auth.users
  for each row execute function public.handle_new_clinicflow_user();

alter table public.profiles enable row level security;
alter table public.clinics enable row level security;
alter table public.clinic_memberships enable row level security;

drop policy if exists "profiles_select_self_or_clinic_staff" on public.profiles;
create policy "profiles_select_self_or_clinic_staff"
on public.profiles
for select to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1
    from public.clinic_memberships staff
    where staff.user_id = (select auth.uid())
      and (
        staff.role = 'super_admin'
          or exists (
            select 1
            from public.clinic_memberships subject
            where subject.user_id = profiles.id
              and subject.clinic_id = staff.clinic_id
          )
        )
  )
);

drop policy if exists "profiles_update_own_name" on public.profiles;
create policy "profiles_update_own_name"
on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists "clinics_select_authenticated" on public.clinics;
create policy "clinics_select_authenticated"
on public.clinics
for select to authenticated
using (
  active
  or exists (
    select 1 from public.clinic_memberships m
    where m.clinic_id = clinics.id
      and m.user_id = (select auth.uid())
  )
);

drop policy if exists "clinic_memberships_select_self_or_admin" on public.clinic_memberships;
create policy "clinic_memberships_select_self_or_admin"
on public.clinic_memberships
for select to authenticated
using (user_id = (select auth.uid()));

revoke all on public.profiles, public.clinics, public.clinic_memberships from anon, authenticated;
grant select on public.profiles, public.clinics, public.clinic_memberships to authenticated;
grant update (full_name) on public.profiles to authenticated;

create or replace function public.create_clinic(
  p_name text,
  p_slug text,
  p_address text default null
)
returns public.clinics
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clinic public.clinics;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'super_admin'
  ) then
    raise exception 'super-admin access required';
  end if;

  if char_length(btrim(coalesce(p_name, ''))) not between 2 and 160
     or p_slug is null
     or p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception 'valid clinic name and slug required';
  end if;

  insert into public.clinics (name, slug, address)
  values (btrim(p_name), p_slug, nullif(btrim(coalesce(p_address, '')), ''))
  returning * into v_clinic;

  insert into public.clinic_memberships (clinic_id, user_id, role)
  values (v_clinic.id, (select auth.uid()), 'super_admin')
  on conflict (clinic_id, user_id) do update
    set role = excluded.role;

  return v_clinic;
end;
$$;

create or replace function public.assign_clinic_staff(
  p_clinic_id uuid,
  p_user_id uuid,
  p_role text
)
returns public.clinic_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_role text;
  v_existing_role text;
  v_membership public.clinic_memberships;
begin
  select p.role into v_actor_role
  from public.profiles p
  where p.id = (select auth.uid());

  if v_actor_role = 'super_admin' then
    null;
  elsif v_actor_role = 'clinic_admin'
    and exists (
      select 1
      from public.clinic_memberships m
      where m.clinic_id = p_clinic_id
        and m.user_id = (select auth.uid())
        and m.role = 'clinic_admin'
    ) then
    null;
  else
    raise exception 'clinic-administrator access required';
  end if;

  if p_role is null or p_role not in ('clinic_admin', 'doctor', 'receptionist') then
    raise exception 'invalid staff role';
  end if;

  if v_actor_role = 'clinic_admin' and p_role = 'clinic_admin' then
    raise exception 'clinic administrators cannot create clinic administrators';
  end if;

  select p.role into v_existing_role
  from public.profiles p
  where p.id = p_user_id
  for update;
  if not found then
    raise exception 'staff account must exist before clinic assignment';
  end if;

  if v_existing_role not in ('patient', p_role) then
    raise exception 'account already has a different global role';
  end if;

  update public.profiles
  set role = p_role, updated_at = now()
  where id = p_user_id;

  insert into public.clinic_memberships (clinic_id, user_id, role)
  values (p_clinic_id, p_user_id, p_role)
  on conflict (clinic_id, user_id) do update
    set role = excluded.role
  returning * into v_membership;

  return v_membership;
end;
$$;

revoke all on function public.create_clinic(text, text, text) from public;
grant execute on function public.create_clinic(text, text, text) to authenticated;
revoke all on function public.assign_clinic_staff(uuid, uuid, text) from public;
grant execute on function public.assign_clinic_staff(uuid, uuid, text) to authenticated;

comment on table public.profiles is
  'ClinicFlow auth profiles; self-registration always creates a patient role.';
comment on table public.clinic_memberships is
  'Clinic-scoped staff roles; all role assignment is performed by authorized RPCs.';
