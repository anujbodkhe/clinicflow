-- Fix the RPC return type mismatch: auth.users.email is varchar, while the
-- declared table result exposes email as text.
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
  select
    auth_user.id::uuid,
    auth_user.email::text,
    profile.full_name::text,
    profile.role::text,
    profile.created_at::timestamptz
  from auth.users auth_user
  join public.profiles profile on profile.id = auth_user.id
  order by lower(coalesce(auth_user.email, '')), auth_user.created_at;
end;
$$;

revoke all on function public.admin_list_users() from public, anon;
grant execute on function public.admin_list_users() to authenticated;