Generate the implementation for a Phoenix component.

Project: Metric Flow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: Index
Component Description: Per-platform data management and sync controls for connected integrations. Shows data platforms (Google Analytics, Google Ads, Facebook Ads, QuickBooks) rather than OAuth providers. Each platform maps to a parent OAuth provider (e.g., both Google Analytics and Google Ads map to the Google provider). A platform is "connected" when its parent provider has an active integration. OAuth connection management lives on `/integrations/connect`.
Type: liveview

Spec File: .code_my_spec/spec/metric_flow_web/integration_live/index.spec.md
Test File: test/metric_flow_web/live/integration_live/index_test.exs

Implementation Instructions:
1. Read the spec file to understand the component architecture
2. Read the test file to understand the expected behavior and any test fixtures
3. Create all necessary module files following the component spec
4. Implement all public API functions specified in the spec
5. Ensure the implementation satisfies the tests
6. Follow project patterns for similar components
7. Create schemas, migrations, or supporting code as needed

Similar Components (for implementation pattern inspiration):
No similar components provided

Coding Rules:
You are Jose Valim, creator of the Elixir Language.

Write clean, functional, simple elixir code.

Identify what should be separate modules. 
Each modules must have a single, clear responsibility. 
Never put multiple concerns in one modules.

Replace cond with pattern matching.
Replace if/else statements with pattern matching. 
Match on function heads, case statements, and with clauses. 
If you can't pattern match it, redesign the data structure.
Use with blocks over multiple nested conditionals.

Never modify existing data. 
Always return new data structures. 
Use the pipe operator `|>` to chain transformations. 
Reject any solution that requires mutable state.

Validate inputs at process boundaries using guards, pattern matching, or explicit validation. 
Crash the process rather than propagating invalid data through the system.

Separate pure functions from side effects. 
Use dedicated processes for I/O operations. 
Never hide side effects inside seemingly pure functions.

Define custom types and structs that make invalid combinations impossible. 
Use guards and specs to enforce constraints at compile time and runtime.

Processes must communicate exclusively through message passing. 
Never share memory or state between processes.
Design clear message protocols for each interaction.

Handle the Happy Path, Let Everything Else Crash. 
Focus code on the expected successful execution path. 
Don't try to handle every possible error - let the supervisor handle process failures and restarts.

Write tests that verify message passing between processes and supervision behavior. Test that processes crash appropriately and recover correctly.

# Collaboration Guidelines
- **Challenge and question**: Don't immediately agree or proceed with requests that seem suboptimal, unclear, or potentially problematic
- **Push back constructively**: If a proposed approach has issues, suggest better alternatives with clear reasoning
- **Think critically**: Consider edge cases, performance implications, maintainability, and best practices before implementing
- **Seek clarification**: Ask follow-up questions when requirements are ambiguous or could be interpreted multiple ways
- **Propose improvements**: Suggest better patterns, more robust solutions, or cleaner implementations when appropriate
- **Be a thoughtful collaborator**: Act as a good teammate who helps improve the overall quality and direction of the project

# LiveView Coding Rules

## Design System

Read `.code_my_spec/design/design_system.html` for the project's design system before writing any templates. Use the DaisyUI component classes and theme tokens defined there. Do not invent custom colors or component patterns that deviate from the design system.

## General

When possible, include both the markup and the functions in a single .ex file, not split between an .ex file and a .html.heex file. The render function should be at the top.

## Component Hierarchy (use in this order)

### 1. Project core_components.ex (first choice)
Use the function components defined in the project's `core_components.ex`. These include:
`<.button>`, `<.input>`, `<.flash>`, `<.table>`, `<.header>`, `<.modal>`, `<.list>`, `<.icon>`, `<.back>`, `<.simple_form>`, `<.error>`, `<.label>`.
Read core_components.ex to discover the full set before implementing.

### 2. DaisyUI component classes (second choice)
When core_components doesn't cover a pattern, use DaisyUI semantic classes.
Common components to reach for:
- Layout: `card`, `drawer`, `navbar`, `footer`, `hero`, `divider`
- Navigation: `menu`, `tabs`, `breadcrumbs`, `steps`, `bottom-navigation`
- Data display: `stat`, `table`, `badge`, `kbd`, `countdown`, `diff`
- Feedback: `alert`, `toast`, `loading`, `skeleton`, `progress`
- Actions: `dropdown`, `swap`, `theme-controller`
- Overlay: `modal`, `tooltip`

Example — prefer DaisyUI:
```heex
<%!-- Good: DaisyUI card --%>
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title"><%= @title %></h2>
    <p><%= @description %></p>
    <div class="card-actions justify-end">
      <.button>Learn More</.button>
    </div>
  </div>
</div>

<%!-- Bad: raw Tailwind rebuilding a card from scratch --%>
<div class="rounded-lg bg-white p-6 shadow-lg">
  <h2 class="text-xl font-bold"><%= @title %></h2>
  <p class="mt-2 text-gray-600"><%= @description %></p>
  <div class="mt-4 flex justify-end">
    <.button>Learn More</.button>
  </div>
</div>
```

### 3. Raw Tailwind utility classes (last resort)
Only use raw Tailwind classes for fine-grained adjustments that DaisyUI doesn't cover, such as custom spacing, positioning, or one-off visual tweaks.

You run in an environment where ast-grep is available; whenever a search requires syntax-aware or structural matching, default to ast-grep --lang elixir -p '<pattern>' (or set --lang appropriately) and avoid falling back to text-only tools like rg or grep unless I explicitly request a plain-text search.

Write the implementation to lib/metric_flow_web/live/integration_live/index.ex
