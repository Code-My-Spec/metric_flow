# Child Implementation: Invitations

Implement the child components listed below. Work in dependency order:

- **Schemas** first (no dependencies)
- **Repositories** next (depend on schemas)
- **Services/GenServers** (depend on repositories and schemas)
- **LiveComponents** before LiveViews (shared components first)
- **LiveViews** last (compose and use shared components)

For each component: write tests first, then implement code.
You can parallelize within a layer (e.g., multiple schemas at once).

## Subagent Usage

- For test prompts: `@"CodeMySpec:test-writer (agent)"`
- For code prompts: `@"CodeMySpec:code-writer (agent)"`

## Completion

Once all subagents have completed, **stop the session** so the hook can validate.
Do not continue to the next phase — the hook will advance you.
