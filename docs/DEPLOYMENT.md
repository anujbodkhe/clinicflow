# ClinicFlow Deployment Checklist

**Do not deploy automatically as part of an ordinary feature task.**

## Pre-deployment
- [ ] Repository audit completed; no unresolved Critical/High security findings.
- [ ] `npm`/package manager scripts and production build pass.
- [ ] Environment variables documented by name in `.env.example`; no real secrets committed.
- [ ] Vercel project is linked to the intended repository and correct project.
- [ ] Supabase project/environment is identified as development, staging, or production.
- [ ] Migration history reconciled with the actual database; pending migrations reviewed.
- [ ] RLS and private storage policies tested with representative roles.
- [ ] Auth redirect URLs, site URL, and allowed origins configured for the target environment.
- [ ] Realtime subscriptions tested with tenant isolation.
- [ ] Demo data is synthetic; no real patient data in screenshots/logs.
- [ ] Error reporting/logging avoids sensitive clinical data.
- [ ] Rollback/recovery approach documented.

## Current repository blockers

- `.env.example` documents the Supabase URL and browser public-key names. No service-role key is used by the inspected app code. D-05 permits advisory summaries only with provider/privacy configuration, which is not set up.
- The repository includes an identity foundation followed by queue, medical, walk-in, PDF, and queue-lifecycle migrations. Supabase CLI 2.121.0 and Docker Desktop's Linux engine now start the local stack; the local migration ledger matches the 12 tracked IDs, and `supabase db lint --local` exits 0 with two unused-variable warnings. No clean reset was run; RLS, Storage, Realtime, and RPC behavior remain unverified.
- `package.json` declares `pnpm@12.3.4`; `pnpm-lock.yaml` is the only package-manager lockfile. Supabase CLI is a pinned dev dependency. Docker CLI 29.9.1 is installed for the current user but has no daemon.
- TypeScript errors are no longer suppressed by `next.config.mjs`. Frozen install, typecheck, five unit tests, and production build passed in RUN-20261020-005/006/007/008. Local SQL lint ran in RUN-20261020-009; RLS behavior, Storage, Realtime, workflow integration, and deployment remain unverified.

## Migration procedure
1. Review the exact migration diff.
2. Verify target project and environment.
3. Back up or confirm recovery path when data is at risk.
4. Apply to isolated development/staging first.
5. Run schema, RLS, and workflow tests.
6. Obtain explicit approval before applying to production.
7. Record the migration and observed result.

## Post-deployment smoke test
- Sign in using each intended demo role.
- Verify clinic membership and denied cross-clinic access.
- Register one online patient and one walk-in in the same test session.
- Verify unique token/order and live updates.
- Verify SOS approval workflow and no-show/standby transitions.
- Verify consultation, prescription PDF, and private download access.
- Verify mobile layout and error handling.
- Confirm no test secrets or patient data are exposed.

A successful Vercel build alone does not establish production readiness.
