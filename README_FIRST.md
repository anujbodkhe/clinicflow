# ClinicFlow — GitHub Copilot Agentic Workflow Starter

## Read this first

This is a documentation and workflow starter for the existing ClinicFlow repository. It is **not** a claim that the current app, database, policies, or workflows already match these documents.

### Installation
1. Download and extract this ZIP.
2. Copy the included `AGENTS.md`, `.github/`, and `docs/` into the root of your existing ClinicFlow repository, merging folders rather than deleting existing files.
3. If a destination file already exists, compare it before replacing it. Keep project-specific working configuration.
4. Open the repository in VS Code with GitHub Copilot enabled.
5. Start with the **Read-only repository audit** prompt in `docs/AGENT_WORKFLOW.md`.
6. Review the audit report before authorizing any implementation.

### Core safety rule
Do not apply migrations, reset databases, alter production data, rotate credentials, deploy, or make destructive changes just because an agent proposes them. Inspect first; produce a plan; request human approval for risky actions.

### Status labels used in these docs
- **Requirement**: intended product behavior.
- **Proposed contract**: design guidance to reconcile with the actual code and database.
- **Verified**: only use after evidence from files, tests, and/or the actual configured environment.
- **Not verified**: never imply that the feature works merely because documentation describes it.

### Current technology direction
Next.js App Router, TypeScript, Supabase PostgreSQL/Auth/private Storage/Realtime, Tailwind CSS, shadcn/ui, lucide-react, and Vercel. Agents must verify actual package versions, project structure, Supabase schema, and deployment configuration before implementation.
