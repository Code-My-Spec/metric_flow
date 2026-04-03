# MetricFlowWeb.OnboardingLive

Post-registration onboarding flow. Guides new users through initial account setup after signup — currently a welcome stub that will expand into a multi-step wizard for connecting integrations and configuring the workspace.

## Type

live_context

## Delegates

None

## Dependencies

- MetricFlow.Accounts
- MetricFlow.Integrations

## Functions

### mount/3

Initializes the onboarding LiveView. Currently a stub that renders a welcome message.

```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Return socket as-is (stub — no data loading yet)

**Test Assertions**:
- renders welcome heading for authenticated user
- redirects unauthenticated user to login

### render/1

Renders the onboarding page with welcome message and future setup steps.

```elixir
@spec render(map()) :: Phoenix.LiveView.Rendered.t()
```

**Process**:
1. Render welcome header and introductory text within Layouts.app wrapper

**Test Assertions**:
- displays "Welcome to MetricFlow" heading
- renders within the app layout
