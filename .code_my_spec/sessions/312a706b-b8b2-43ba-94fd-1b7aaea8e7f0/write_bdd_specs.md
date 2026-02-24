# Write BDD Specs: Account Deletion (Owner Only)

**Story ID**: 455

A detailed prompt has been written to: `.code_my_spec/sessions/312a706b-b8b2-43ba-94fd-1b7aaea8e7f0/subagent_prompts/bdd_specs_story_455.md`

## Instructions

Use the `@"CodeMySpec:bdd-spec-writer (agent)"` subagent to generate BDD specifications for this story.

Pass it the prompt file path above. The prompt contains:
- Story context and acceptance criteria with expected file paths
- Component type and testing approach (LiveView, Controller, etc.)
- Spex DSL syntax guide and shared givens

The bdd-spec-writer agent will:
1. Write ONE spec file per criterion
2. Run `mix compile` to verify it compiles
3. Stop and return for validation after each file

After each spec file is written, validation will check that the file exists, parses correctly,
has scenarios with Given/When/Then steps, and compiles. Fix any issues before proceeding to the next criterion.
