<!-- cms:task type="LiveViewSpec" component="MetricFlowWeb.UserLive.Login" -->

Generate a LiveView spec for the following.
Project: Metric FLow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: Login
Component Description: User login and session management.
Type: liveview

Existing Implementation: lib/metric_flow_web/live/user_live/login.ex
Existing tests: test/metric_flow_web/live/user_live/login_test.exs


Design Rules:
# Collaboration Guidelines
- **Challenge and question**: Don't immediately agree or proceed with requests that seem suboptimal, unclear, or potentially problematic
- **Push back constructively**: If a proposed approach has issues, suggest better alternatives with clear reasoning
- **Think critically**: Consider edge cases, performance implications, maintainability, and best practices before implementing
- **Seek clarification**: Ask follow-up questions when requirements are ambiguous or could be interpreted multiple ways
- **Propose improvements**: Suggest better patterns, more robust solutions, or cleaner implementations when appropriate
- **Be a thoughtful collaborator**: Act as a good teammate who helps improve the overall quality and direction of the project

- Structure applications as hierarchical supervision trees
- Put critical, stable processes at the top and volatile, expendable processes at the bottom
- Use OTP behaviors (GenServer, Supervisor, GenStateMachine) as design patterns for processes.
- Don't try to handle every edge case
- Fail predictably and quickly and recover automatically using supervision
- Design the application as independent processes, communicating via message passing
- Each process should have a single, clear responsibility with well-defined boundaries
- Model complex business processes as explicit state machines using GenStateMachine or similar patterns
- Design for distribution from day one, using distributed Erlang capabilities for seamless process communication across nodes
- Architect applications so components can be upgraded, replaced, or scaled without system shutdown using hot code swapping
- Design a functional core containing pure business logic and an imperative shell handling side effects
- The shell can call the core, but not vice versa

Use coordination contexts for cross-context operations instead of adopting layered architectures. Create explicit coordination modules when operations span multiple bounded contexts while maintaining context autonomy.

Design Phoenix Contexts as bounded context boundaries that decouple and isolate parts of your application, following Domain-Driven Design principles. Each context should encapsulate data access, validation, and business logic for a specific domain with clear boundaries.

# LiveView Design Documentation Rules

## Purpose
These rules ensure consistent, complete design documentation for Phoenix LiveViews and components before implementation.

## Design System

Before building any UI, read `.code_my_spec/design/design_system.html` for the project's design system. Use the DaisyUI component classes and theme tokens defined there. Do not invent custom colors or component patterns that deviate from the design system.

## Guidelines

Keep liveviews small and focused.
Each liveview should correspond to a path. No modifying the UI implicitly without a path change.

## LiveView Design Template

### File Structure
- Place in `docs/design/my_app_web/{context}_live/`
- Name files by function: `index.md`, `show.md`, `form.md`

### Required Sections

1. **Purpose** - Single sentence/short paragraph describing what this LiveView does
2. **Route** - The URL pattern that renders this LiveView
3. **Context Access** - List the context functions this LiveView calls
4. **LiveView Structure** - Three subsections:
   - **Mount** - What happens when LiveView initializes
   - **Events** - User interactions and their handlers
   - **Template** - UI structure and components used
5. **Data Flow** - Numbered steps of the user journey
6. **Security** - Permission checks and authorization rules
7. **Real-time Updates** - PubSub subscriptions and live updates (if applicable)

## Style Guidelines

- **Be concise** - Each section should be brief but complete
- **Use bullets** - Structure information as bullet points
- **Include context calls** - Show exactly which context functions are used
- **Show code examples** - Provide HEEx usage examples for components
- **Focus on behavior** - Describe what happens, not how it's implemented
- **Consider security** - Always include permission and authorization concerns
- **Plan for real-time** - Consider PubSub integration for live updates

You run in an environment where ast-grep is available; whenever a search requires syntax-aware or structural matching, default to ast-grep --lang elixir -p '<pattern>' (or set --lang appropriately) and avoid falling back to text-only tools like rg or grep unless I explicitly request a plain-text search.

Document Specifications:
# Liveview

LiveView spec documents define Phoenix LiveView pages including routing,
user interactions, layout design, and dependencies. They follow a UI-focused
format describing what the view does and how it looks, with detailed function
specifications for mount, handle_event, and render callbacks.

Specs should focus on WHAT the view does, not HOW it does it. Keep them concise
and human-readable, as they're consumed by both humans and AI agents.


## Required Sections

### Route

Format:
- Use H2 heading
- Single line with the URL path pattern in backticks

Content:
- Define the URL path pattern for this LiveView
- Use colon-prefixed parameters for dynamic segments (e.g., `:id`, `:slug`)

Examples:
- ## Route
  `/accounts/:id/manage`


### User Interactions

Format:
- Use H2 heading
- Bold event names with descriptions

Content:
- Map each user action to its behavior and context calls
- Use Phoenix event format (phx-change, phx-submit, phx-click)
- Describe what happens and which context function is called

Examples:
- ## User Interactions
  - **phx-submit="save"**: Validate form params, call Accounts.update_account/2, flash success or show errors.
  - **phx-change="validate"**: Live-validate form inputs and update changeset in assigns.


### Dependencies

Format:
- Use H2 heading
- Simple bullet list of module names

Content:
- Each item must be a valid Elixir module name (PascalCase)
- No descriptions - just the module names
- Only include modules this module depends on

Examples:
- ## Dependencies
  - CodeMySpec.Components
  - CodeMySpec.Utils


### Design

Format:
- Use H2 heading
- Structured prose describing layout, components, and responsive behavior

Content:
- Describe the layout structure (sidebar, grid, single-column, etc.)
- List DaisyUI component choices (e.g., .card, .btn-primary, .form-control)
- Describe responsive behavior
- This is a structural description, not renderable HTML

Examples:
- ## Design
  Layout: Centered single-column page
  Main content:
    - Card: Account settings form (name, description fields)
    - Card.danger: Delete account section (owners only, with confirmation)
  Components: .card, .form-control, .btn-primary, .btn-error
  Responsive: Stack cards vertically on mobile


## Optional Sections

### Params

Format:
- Use H2 heading
- Bullet list of parameter names and types, or "None"

Content:
- Document URL parameters and their types
- Only include path and query parameters relevant to this LiveView

Examples:
- ## Params
  - `id` - integer, account ID
- ## Params
  None


### Components

Format:
- Use H2 heading
- Bullet list of child component module names, or "None"

Content:
- List LiveView components (function components, live components) used by this view
- Include brief description of each component's role

Examples:
- ## Components
  - AccountLive.Components.Navigation - sidebar navigation with active tab
  - AccountLive.Components.SettingsForm - account settings form
- ## Components
  None



Write the document to .code_my_spec/spec/metric_flow_web/user_live/login.spec.md.
