# Write BDD Specs: Password Reset Flow

**Story ID**: 456

A detailed prompt has been written to: `.code_my_spec/sessions/3c2b038c-4ee0-4c33-b1b6-f9b9fa6c0524/subagent_prompts/bdd_specs_story_456.md`

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
