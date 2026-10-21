# Test Environment Safety

No Supabase test environment is running or verified. Supabase CLI is a project dependency and Docker CLI is installed per-user; the Docker engine is absent because Docker Desktop installation requires Windows administrator approval. Before integration, security, or end-to-end tests:

1. Obtain owner authorization for an isolated local/non-production Supabase target.
2. Use the repository-owned base schema recorded under D-06 and verify the migration sequence against a disposable local database without applying changes to a live project.
3. Use synthetic accounts, clinics, sessions, queue entries, and documents only; see [`../TEST_DATA.md`](../TEST_DATA.md).
4. Confirm the application points to the intended test endpoint before any write. Do not print environment values.
5. Document a reviewed fixture and cleanup plan. Do not reset or broadly delete shared data.

Source-observed variable names are documented in `../TEST_DATA.md`; values are intentionally omitted. A missing test target or safe schema is a blocker, not permission to use production.
