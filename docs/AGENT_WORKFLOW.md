# ClinicFlow — Agentic Workflow

## Recommended cycle
Use one primary agent for the task and ask the other agents to review. Avoid several agents editing the same files concurrently.

1. **Audit** — `repo-auditor` inspects the repository without edits.
2. **Plan** — primary Copilot Chat creates a small plan with acceptance criteria and risks.
3. **Implement** — `feature-implementer` implements one approved vertical slice.
4. **Test** — `test-engineer` adds/runs relevant tests.
5. **Review** — `security-reviewer` inspects the diff, permissions, RLS, and sensitive flows.
6. **Human approval** — review diff and migration; only then merge/deploy/apply changes.

## Prompt 1 — Read-only repository audit
Paste this first in Copilot Chat and select the repo-auditor agent if available:

> Perform a READ-ONLY audit of the existing ClinicFlow repository. Read AGENTS.md, .github/copilot-instructions.md, and the docs. Inspect the actual Next.js code, package scripts, Supabase clients, auth, migrations, generated database types, RLS policies available in the repo, storage usage, Realtime, queue operations, tests, and deployment config. Do not edit files, apply migrations, connect to or modify production data, seed data, or deploy. Report verified/partial/missing/not-verifiable status for each feature and cite exact file paths/symbols. Identify conflicts between docs, code, migrations, and schema drafts. Run only safe, non-destructive checks that are already configured and report exact results. End with the three highest-priority blockers and the smallest safe next vertical slice.

## Prompt 2 — Plan one task
> Based on the approved audit, propose one small end-to-end implementation slice. Include user-visible behavior, files to change, schema/RLS impact, authorization rules, tests, rollback considerations, and acceptance criteria. Do not edit anything yet. If the actual schema is unknown or conflicts with the plan, stop and explain what must be verified.

## Prompt 3 — Implement approved slice
> Implement only the approved plan. First re-check the relevant existing code and schema. Do not add unrelated features or replace the architecture. Follow AGENTS.md. If a migration is needed, create the migration file but do not apply it to any live database. Add tests and run the available relevant checks. Report actual changes, commands/results, risks, and anything not verified.

## Prompt 4 — Independent security review
> Review the current diff as a read-only security reviewer. Focus on authentication, server-side authorization, Supabase RLS, cross-clinic isolation, private storage, secrets, queue concurrency, SOS approval, and clinical data exposure. List findings with severity and file/symbol evidence. Do not edit code or claim security certification.

## Prompt 5 — Release readiness
> Audit release readiness without deploying or modifying any environment. Use docs/DEPLOYMENT.md and docs/TESTING_AND_ACCEPTANCE.md. Report each item PASS/FAIL/BLOCKED/NOT VERIFIED with evidence. A passing build alone is not sufficient. Do not run migrations or expose secrets.

## Agent coordination rules
- One implementation owner per task.
- Reviewer/auditor agents are read-only unless explicitly reassigned.
- Do not let agents independently invent competing schemas.
- If a task touches queue invariants, RLS, auth, or clinical data, require a security review.
- Keep work in small commits/PRs when the repository workflow supports them.
- Never approve or deploy solely because an agent says the task is complete.
