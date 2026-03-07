# Child Component Designs: Invitations

Design specifications for the child components listed below.
You can invoke multiple subagents in parallel — child specs are independent.

## Subagent Usage

For each component, invoke `@"CodeMySpec:spec-writer (agent)"` to:
1. Read the prompt file
2. Follow the instructions to create the specification
3. Write the spec file to the specified location

## Completion

Once all subagents have completed, **stop the session** so the hook can validate.
Do not continue to the next phase — the hook will advance you.
