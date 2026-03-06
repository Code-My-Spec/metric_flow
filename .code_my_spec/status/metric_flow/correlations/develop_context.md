# Context Lifecycle: Correlations

You are orchestrating the full development lifecycle for this context.

## Lifecycle Phases

1. **Context Spec** - Define the bounded context architecture
2. **Component Specs** - Design each child component
3. **Design Review** - Validate architecture before implementation
4. **Implementation** - Tests + code per component in dependency order

## Current Phase: Implementation

Implement in dependency order:
- **Schemas** first (no dependencies)
- **Repositories** next (depend on schemas)
- **Services/Logic** (depend on repositories and schemas)
- **Context module** last (delegates to and coordinates all the above)

For each component: write tests first, then implement code. Verify tests pass before moving to the next component.

Components to implement:

- **CorrelationWorker** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/correlations/metricflow_correlations_correlationworker_test.md`
  - [x] Code: passing
- **Math** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/correlations/metricflow_correlations_math_test.md`
  - [x] Code: passing

For each component, invoke the appropriate subagent with the prompt file:
- Test prompts: `@"CodeMySpec:test-writer (agent)"`
- Code prompts: `@"CodeMySpec:code-writer (agent)"`


## Subagent Usage

Invoke the appropriate subagent for each prompt file:

- For spec prompts: `@"CodeMySpec:spec-writer (agent)"`
- For design review prompts: `@"CodeMySpec:spec-writer (agent)"`
- For test prompts: `@"CodeMySpec:test-writer (agent)"`
- For code prompts: `@"CodeMySpec:code-writer (agent)"`

## Workflow

1. Complete all tasks listed above for the current phase
2. **Stop the session** — end your turn so the stop hook can validate your work
3. The stop hook will check your progress and provide instructions for the next phase
4. If the hook blocks the stop, follow its feedback and repeat from step 1

**Important:** You must stop after completing each phase. Do not attempt to
continue to the next phase on your own — the stop hook generates the prompt
files you need for each subsequent phase.
