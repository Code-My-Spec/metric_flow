# MetricFlowWeb.OnboardingLive.Index

Welcome page and entry point for the onboarding flow. Displays a welcome message and introductory text to guide new users through account setup.

## Type

module

## Delegates

None

## Dependencies

- MetricFlow.Accounts
- MetricFlow.Integrations

## Functions

### mount/3

Initializes the onboarding LiveView with page title.

```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Assign page title "Onboarding" to socket

**Test Assertions**:
- renders welcome heading for authenticated user
- redirects unauthenticated user to login

### render/1

Renders the onboarding welcome page within the app layout.

```elixir
@spec render(map()) :: Phoenix.LiveView.Rendered.t()
```

**Process**:
1. Wrap content in Layouts.app with flash, current_scope, and white_label_config
2. Render centered welcome header and introductory setup text

**Test Assertions**:
- displays "Welcome to MetricFlow" heading
- renders introductory setup text
