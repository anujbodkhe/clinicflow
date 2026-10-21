# Unit tests

Run the deterministic queue-rule tests with:

```powershell
node --experimental-strip-types --test tests/unit/*.test.ts
```

These tests cover queue ordering, position, EWT elapsed-time clamping, and the first/second missed-turn helper transitions. They do not prove SQL migration, RPC authorization, RLS, Realtime, or rendered UI behavior; those require isolated Supabase integration and browser checks.
