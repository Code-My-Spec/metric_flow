# Context Lifecycle: Agencies

You are orchestrating the full development lifecycle for this context.

## Lifecycle Phases

1. **Context Spec** - Define the bounded context architecture
2. **Component Specs** - Design each child component
3. **Design Review** - Validate architecture before implementation
4. **Tests** - Write tests for each component
5. **Code** - Implement each component

## Current Phase: Component Specifications

Prompt files to complete:

- [ ] AutoEnrollmentRule: `docs/status/metric_flow/agencies/metricflow_agencies_autoenrollmentrule_component_spec.md`
- [ ] AgenciesRepository: `docs/status/metric_flow/agencies/metricflow_agencies_agenciesrepository_component_spec.md`
- [ ] WhiteLabelConfig: `docs/status/metric_flow/agencies/metricflow_agencies_whitelabelconfig_component_spec.md`

Read each prompt file and invoke the appropriate subagent.


## Subagent Usage

Invoke the appropriate subagent for each prompt file:

- For spec prompts: `@"CodeMySpec:spec-writer (agent)"`
- For test prompts: `@"CodeMySpec:test-writer (agent)"`
- For code prompts: `@"CodeMySpec:code-writer (agent)"`

## Workflow

1. Complete all tasks in the current phase
2. The stop hook will validate and advance to the next phase
3. Continue until all phases complete

## Completion

The stop hook will validate:
- All spec files exist and are valid
- Design review passes
- All tests compile and align with specs
- All implementations pass tests
