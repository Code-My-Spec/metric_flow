# Project Development Guide

This guide describes how the project's `.code_my_spec/` directory works so you can locate what you need efficiently.

## Project Structure

```
.code_my_spec/
├── architecture/          ← System component graph and dependencies
├── status/                ← Implementation status of every component
├── spec/                  ← Specifications for every module
├── rules/                 ← Coding standards by component type
├── knowledge/             ← Project-specific operational knowledge
├── framework/             ← Framework reference (LiveView, DaisyUI, etc.) [symlink]
├── tools/                 ← Helper scripts (set-story-component, etc.) [symlink]
├── design/                ← Design system assets
├── issues/                ← Known bugs and technical debt
└── qa/                    ← QA test results
```

## Progressive Disclosure: Where to Look

### 1. Orientation — What exists and how it's organized

Start here to understand the system shape.

| Need | File |
|---|---|
| List of all components, types, and dependencies | `.code_my_spec/architecture/overview.md` |
| Hierarchical tree view by Elixir namespace | `.code_my_spec/architecture/namespace_hierarchy.md` |
| Dependency graph (Mermaid) | `.code_my_spec/architecture/dependency_graph.mmd` |

### 2. Status — What's done and what's not

Check here before starting work on a component.

| Need | File |
|---|---|
| Top-level status of all contexts | `.code_my_spec/status/metric_flow.md` |
| Web layer status | `.code_my_spec/status/metric_flow_web.md` |
| Status of a specific context | `.code_my_spec/status/metric_flow/<context_name>.md` |

Status files use a checklist format:
```
- [ ] spec_file - Context specification file exists
- [x] implementation_file - Component implementation file exists
- [ ] test_file - Component test file exists
- [x] tests_passing - Component tests are passing
```

### 3. Specifications — What a module should do

Read before implementing or modifying any module.

| Need | File |
|---|---|
| Spec for a module | `.code_my_spec/spec/<module_path>.spec.md` |

Specs follow a standard format:
- **Title**: Fully qualified module name with type
- **Delegates**: Functions delegated to other modules
- **Functions**: Public API with `@spec`, process steps, and test assertions
- **Dependencies**: Required modules
- **Fields**: (schemas only) Ecto field definitions

Spec paths mirror the Elixir module namespace.

### 4. Rules — Coding standards for each component type

Read before writing code. Rules are scoped by component type.

| Component Type | Design Rules | Test Rules |
|---|---|---|
| Context | `.code_my_spec/rules/context_design.md` | — |
| Repository | `.code_my_spec/rules/repository_design.md` | `.code_my_spec/rules/repository_test.md` |
| Schema | `.code_my_spec/rules/schema_design.md` | — |
| LiveView | `.code_my_spec/rules/liveview_design.md` | — |
| LiveView component | `.code_my_spec/rules/liveview_component_design.md` | — |
| Elixir (general) | `.code_my_spec/rules/elixir_design.md` | `.code_my_spec/rules/elixir_test.md` |

### 5. Design System — Visual reference

Read before building any UI (LiveViews, components, templates).

| Need | File |
|---|---|
| Design system (colors, typography, components) | `.code_my_spec/design/design_system.html` |

Open the HTML file in a browser to see the full visual reference. Use the DaisyUI classes and theme tokens defined there.

### 6. Issues — Known problems and technical debt

Check before working in an area to avoid known pitfalls.

Issues live in `.code_my_spec/issues/` as individual markdown files describing the problem, reproduction steps, and possible solutions.

### 7. Knowledge — Operational knowledge

- `.code_my_spec/knowledge/` — Project-specific research (data providers, auth flows, etc.)
- `.code_my_spec/framework/` — Framework knowledge (LiveView, DaisyUI, Boundary, etc.) [symlink]

## Phoenix Contexts Architecture

All code follows Phoenix Contexts conventions:

- **Contexts** are the public API boundary. They live at `lib/metric_flow/<context_name>.ex` and delegate to child modules.
- **Repositories** handle data access. They live under the context namespace.
- **Schemas** define Ecto schemas. They live under the context namespace.
- **Scope** is the first parameter to all public context functions. It carries user, account, project, and optionally working directory.

### Key Conventions

- All public functions accept `%Scope{}` as the first parameter
- Database queries filter by scope foreign keys
- Return consistent `{:ok, result}` / `{:error, reason}` tuples

## Working with .code_my_spec/

**Before implementing a component:**
1. Check `.code_my_spec/status/` — is it already done?
2. Read `.code_my_spec/spec/` — what should it do?
3. Read `.code_my_spec/rules/` — what conventions apply to this component type?
4. Check `.code_my_spec/issues/` — are there known problems in this area?

**Before modifying an existing component:**
1. Read the spec to understand the intended behavior
2. Read the current implementation
3. Check if there are open issues related to it
4. Follow the rules for that component type

**When you need context on the bigger picture:**
1. Read `.code_my_spec/architecture/namespace_hierarchy.md` for the component tree
2. Read `.code_my_spec/architecture/overview.md` for dependency relationships
