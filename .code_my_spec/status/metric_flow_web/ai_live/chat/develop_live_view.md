# LiveView Lifecycle: Chat

You are orchestrating the full development lifecycle for this LiveView.

## Lifecycle Phases

1. **LiveView Spec** - Define the LiveView architecture, route, interactions
2. **Component Specs** - Design each child component
3. **Implementation** - Tests + code in dependency order (children first, parent last)

## Current Phase: Implementation

Implement in dependency order:
- **Children** first (child components have no cross-dependencies)
- **Parent LiveView** last (composes and coordinates all children)

For each component: write tests first, then implement code. Verify tests pass before moving to the next component.

Components to implement:

- **Chat** (liveview)
  - [ ] Test: `.code_my_spec/status/metric_flow_web/ai_live/chat/metricflowweb_ailive_chat_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow_web/ai_live/chat/metricflowweb_ailive_chat_code.md`

For each component, invoke the appropriate subagent with the prompt file:
- Test prompts: `@"CodeMySpec:test-writer (agent)"`
- Code prompts: `@"CodeMySpec:code-writer (agent)"`


## Subagent Usage

Invoke the appropriate subagent for each prompt file:

- For spec prompts: `@"CodeMySpec:spec-writer (agent)"`
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
