# Write BDD Specs: Connect Financial Platform via OAuth

**Story ID**: 435

A detailed prompt has been written to: `.code_my_spec/tasks/stories/435/subagent_prompts/bdd_specs_prompt.md`

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
