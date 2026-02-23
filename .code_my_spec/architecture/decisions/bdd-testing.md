# BDD Testing with SexySpex

## Status

Accepted

## Context

MetricFlow uses behavior-driven development (BDD) to ensure all user story acceptance
criteria are covered by executable specifications. Tests should map directly to user
stories and be readable by non-technical stakeholders.

## Options Considered

### SexySpex (BDD Framework)

Custom BDD framework providing given/when/then step definitions, shared givens,
and integration with Phoenix test infrastructure.

- Run via `mix spex` (not `mix test`)
- Step functions: `given_` returns `{:ok, context}`, `when_` returns `{:ok, context}`,
  `then_` returns `:ok`
- Shared givens in `test/spex/shared_givens.ex`
- Specs live in `test/spex/{story_id}/` directories
- Uses `SexySpex` and `MetricFlowTest.ConnCase` for test setup

### Cabbage / White Bread

Elixir BDD frameworks using Gherkin feature files.

- Gherkin syntax (`.feature` files) with step definition modules
- More ceremony — feature files separate from step implementations
- Smaller communities, less active maintenance

### Plain ExUnit with Descriptive Names

Standard ExUnit tests with `describe` blocks matching acceptance criteria.

- No additional framework dependency
- Less structured — no enforced given/when/then pattern
- Harder to trace tests back to specific story criteria

## Decision

**SexySpex as the BDD testing framework.**

SexySpex provides a structured given/when/then pattern that maps directly to user story
acceptance criteria. Each spec file tests one criterion and is organized by story ID,
making it trivial to verify story coverage.

Key conventions:
- Module names under `MetricFlowSpex` namespace
- Each spec needs: `use SexySpex`, `use MetricFlowTest.ConnCase`,
  `import_givens MetricFlowSpex.SharedGivens`, `import Phoenix.LiveViewTest`
- Use `context.conn` for authenticated routes, `build_conn()` for unauthenticated
- Specs MUST test real behavior — test against actual routes even if they don't exist yet
  (tests should fail until the feature is implemented — that's the BDD red-green-refactor cycle)

## Consequences

- `{:sexy_spex, path: "/path/to/spex"}` as a local dependency
- Specs run via `mix spex` with `--quiet` flag
- Spec files in `test/spex/` are compiled via `elixirc_paths(:test)`
- BDD specs drive feature implementation — write specs first, then implement until they pass
- SharedGivens provide reusable setup steps across stories
