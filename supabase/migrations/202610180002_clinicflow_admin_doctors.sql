-- ClinicFlow: authorized doctor lookup for clinic administration.
-- Apply through the explicit Supabase migration approval flow.

create or replace function public.list_manageable_doctors(p_clinic_id uuid)
returns table (id uuid, full_name text)
language sql
security definer
set search_path = ''
as $$
  select p.id, p.full_name
  from public.profiles p
  join public.clinic_memberships doctor_membership
    on doctor_membership.user_id = p.id
   and doctor_membership.clinic_id = p_clinic_id
   and doctor_membership.role = 'doctor'
  where exists (
    select 1
    from public.clinic_memberships admin_membership
    where admin_membership.clinic_id = p_clinic_id
      and admin_membership.user_id = (select auth.uid())
      and admin_membership.role in ('super_admin', 'clinic_admin')
  )
  order by p.full_name, p.id;
$$;

revoke execute on function public.list_manageable_doctors(uuid) from public;
grant execute on function public.list_manageable_doctors(uuid) to authenticated;
