# ClinicFlow

ClinicFlow is a Next.js 16 App Router application for a multi-clinic virtual queue and clinic workflow. It uses Supabase for authentication, PostgreSQL, private Storage, and Realtime.

## Local setup

1. Use Node.js 24 and the declared package manager (`pnpm@12.3.4`) via Corepack. Run `corepack pnpm@12.3.4 install`. The Supabase CLI is a project dev dependency; invoke it with `corepack pnpm@12.3.4 exec supabase`.
2. Install and start Docker Desktop with administrator approval. The standalone Docker CLI can be installed per-user with `winget install --id Docker.DockerCLI --exact --scope user`, but it is only a client: Supabase also needs a running Linux-container Docker engine. On Windows, ensure Docker Desktop's `resources\bin` directory is on the process `PATH` so Docker's configured credential helper can run. Then run `corepack pnpm@12.3.4 exec supabase start` from the repository root. This starts local services and does not access a hosted project.
3. Run `corepack pnpm@12.3.4 exec supabase db reset` only against the local Supabase stack to apply the tracked migration chain from scratch. Do not point this operation at a hosted project.
4. Copy `.env.example` to `.env.local`, then replace its Supabase URL/client keys with the values for the intended environment. For local development, use the local API URL and publishable client key from `supabase status`; do not use hosted-project values for local verification. Next.js reads `.env.local`, not `.env.example`. The `NEXT_PUBLIC_SUPABASE_ANON_KEY` entry is a legacy fallback. `supabase status` also prints local secret/service keys: do not share or paste its full output, and never put those secret keys in `NEXT_PUBLIC_*` variables.
5. Start the app with `corepack pnpm@12.3.4 dev`, then open `http://localhost:3000`. Sign up at `/auth/sign-up` and sign in at `/auth/login`.
6. For local-only bootstrap, use Supabase Studio's SQL editor to inspect `auth.users`, then promote the verified local account and create a local clinic/membership with its exact UUID:

   ```sql
   with operator as (
     update public.profiles
     set role = 'super_admin', updated_at = now()
     where id = '<verified-local-auth-user-uuid>'
       and role = 'patient'
     returning id
   ),
   clinic as (
     insert into public.clinics (name, slug, address)
     select 'Local Demo Clinic', 'local-demo', 'Local test address'
     from operator
     returning id
   )
   insert into public.clinic_memberships (clinic_id, user_id, role)
   select clinic.id, operator.id, 'super_admin'
   from clinic cross join operator;
   ```

   Confirm the statement inserts one membership. It creates nothing if the profile UUID is not an existing patient. Keep these operator actions local; hosted provisioning requires a separate reviewed procedure.

Available checks: `corepack pnpm@12.3.4 typecheck` and `corepack pnpm@12.3.4 test`.

## Database and release limitations

Tracked migrations now include a repository-owned identity/tenant foundation followed by queue, medical-record, prescription, walk-in, and queue-lifecycle migrations. A local Supabase config is included. The local Supabase stack is now running, and its migration ledger matches all 12 tracked migration IDs. Local database lint completed with two unused-variable warnings. RLS behavior, RPC behavior, Storage, and Realtime still require targeted runtime tests; the Vector log-collection container is unhealthy because Docker Desktop's configured TCP log endpoint is not reachable. Do not enable unauthenticated Docker TCP access as a workaround.

No live Supabase project or deployment has been accessed or verified. Never apply these migrations to an unknown or hosted project without a separate schema review and explicit approval. Queue behavior, RLS, Storage permissions, Realtime, and user workflows require validation in a dedicated isolated environment. D-07 remains unresolved; clinical production use is not approved.

Automated checks currently cover deterministic queue-rule helpers only; they do not test database migrations/RLS or complete application workflows. Linting, browser tests, and integration tests against local Supabase are not configured.

Never expose service-role keys, AI-provider credentials, or other secrets in browser code or committed configuration. The Supabase publishable/anon key is intended for client use in conjunction with correct RLS.
