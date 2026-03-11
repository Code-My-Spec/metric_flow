# Write BDD Specifications for Story

Create BDD specification files using the Spex DSL for the following story and its acceptance criteria.

## Story Context

**ID**: 435
**Title**: Connect Financial Platform via OAuth
**Description**: As a client user, I want to connect my QuickBooks account so that my revenue data can be correlated with marketing metrics.
**Priority**: 26

## Component Under Test

**Module**: `MetricFlowWeb.IntegrationLive.Connect`
**Type**: liveview

## Acceptance Criteria

### Criterion 4025: User can initiate OAuth flow for QuickBooks

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/435_connect_financial_platform_via_oauth/criterion_4025_user_can_initiate_oauth_flow_for_quickbooks_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER — Wallaby browser testing):**
- **Test what users SEE and DO** - not internal function calls
- Use `Wallaby.DSL` + `Wallaby.Query` for real browser interactions
- Navigate with `visit/2` - use plain string paths, not `~p` sigils
- Use `fill_in/3` + `click/2` for form interactions
- Assert with `assert_has/2`, `refute_has/2`, `current_path/1`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
```


### Criterion 4026: OAuth flow authenticates user and grants access to financial data

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/435_connect_financial_platform_via_oauth/criterion_4026_oauth_flow_authenticates_user_and_grants_access_to_financial_data_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER — Wallaby browser testing):**
- **Test what users SEE and DO** - not internal function calls
- Use `Wallaby.DSL` + `Wallaby.Query` for real browser interactions
- Navigate with `visit/2` - use plain string paths, not `~p` sigils
- Use `fill_in/3` + `click/2` for form interactions
- Assert with `assert_has/2`, `refute_has/2`, `current_path/1`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
```


### Criterion 4027: After successful authentication, user can select which income accounts to track

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/435_connect_financial_platform_via_oauth/criterion_4027_after_successful_authentication_user_can_select_which_income_accounts_to_track_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER — Wallaby browser testing):**
- **Test what users SEE and DO** - not internal function calls
- Use `Wallaby.DSL` + `Wallaby.Query` for real browser interactions
- Navigate with `visit/2` - use plain string paths, not `~p` sigils
- Use `fill_in/3` + `click/2` for form interactions
- Assert with `assert_has/2`, `refute_has/2`, `current_path/1`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
```


### Criterion 4028: User can select multiple income accounts, system will sum debits and credits

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/435_connect_financial_platform_via_oauth/criterion_4028_user_can_select_multiple_income_accounts_system_will_sum_debits_and_credits_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER — Wallaby browser testing):**
- **Test what users SEE and DO** - not internal function calls
- Use `Wallaby.DSL` + `Wallaby.Query` for real browser interactions
- Navigate with `visit/2` - use plain string paths, not `~p` sigils
- Use `fill_in/3` + `click/2` for form interactions
- Assert with `assert_has/2`, `refute_has/2`, `current_path/1`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
```


### Criterion 4029: Integration is saved only after successful OAuth completion

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/435_connect_financial_platform_via_oauth/criterion_4029_integration_is_saved_only_after_successful_oauth_completion_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER — Wallaby browser testing):**
- **Test what users SEE and DO** - not internal function calls
- Use `Wallaby.DSL` + `Wallaby.Query` for real browser interactions
- Navigate with `visit/2` - use plain string paths, not `~p` sigils
- Use `fill_in/3` + `click/2` for form interactions
- Assert with `assert_has/2`, `refute_has/2`, `current_path/1`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
```


### Criterion 4030: User sees confirmation that QuickBooks is connected and ready to sync

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/435_connect_financial_platform_via_oauth/criterion_4030_user_sees_confirmation_that_quickbooks_is_connected_and_ready_to_sync_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER — Wallaby browser testing):**
- **Test what users SEE and DO** - not internal function calls
- Use `Wallaby.DSL` + `Wallaby.Query` for real browser interactions
- Navigate with `visit/2` - use plain string paths, not `~p` sigils
- Use `fill_in/3` + `click/2` for form interactions
- Assert with `assert_has/2`, `refute_has/2`, `current_path/1`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
```


### Criterion 4031: Failed OAuth attempts show clear error messages

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/435_connect_financial_platform_via_oauth/criterion_4031_failed_oauth_attempts_show_clear_error_messages_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER — Wallaby browser testing):**
- **Test what users SEE and DO** - not internal function calls
- Use `Wallaby.DSL` + `Wallaby.Query` for real browser interactions
- Navigate with `visit/2` - use plain string paths, not `~p` sigils
- Use `fill_in/3` + `click/2` for form interactions
- Assert with `assert_has/2`, `refute_has/2`, `current_path/1`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
```


### Criterion 4032: Financial data (debits and credits) becomes just another metric in the system for correlation

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/435_connect_financial_platform_via_oauth/criterion_4032_financial_data_debits_and_credits_becomes_just_another_metric_in_the_system_for_correlation_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER — Wallaby browser testing):**
- **Test what users SEE and DO** - not internal function calls
- Use `Wallaby.DSL` + `Wallaby.Query` for real browser interactions
- Navigate with `visit/2` - use plain string paths, not `~p` sigils
- Use `fill_in/3` + `click/2` for form interactions
- Assert with `assert_has/2`, `refute_has/2`, `current_path/1`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
```


## LiveView Testing Guide

This is a LiveView component. **Test at the SURFACE layer** using Wallaby (real browser testing).

### Key Principles

- **Test what users SEE** - assert on visible text, element presence, page content
- **Test what users DO** - fill in forms, click buttons, navigate links
- **DON'T call context functions or fixtures** - all state setup through the browser
- **Assert on user feedback** - flash messages, error text, success confirmations

### Required Setup

**IMPORTANT**: Use `Wallaby.DSL` and `Wallaby.Query` — NOT ConnCase or LiveViewTest.
The setup block creates a Wallaby browser session with Ecto sandbox integration.

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
```

**Note:** Use plain strings for paths (e.g., `"/users/register"`) instead of the `~p` sigil.

### Wallaby Testing Patterns

**Navigating to a page:**
```elixir
given_ "the registration page is loaded", context do
  session = context.session |> visit("/users/register")
  {:ok, Map.put(context, :session, session)}
end
```

**Filling in forms and submitting:**
```elixir
when_ "user submits valid credentials", context do
  session = context.session
    |> fill_in(text_field("Email"), with: "test@example.com")
    |> fill_in(text_field("Password"), with: "SecurePass123!")
    |> click(button("Create account"))
  {:ok, Map.put(context, :session, session)}
end
```

**Clicking buttons/links:**
```elixir
when_ "user clicks the submit button", context do
  session = context.session |> click(button("Submit"))
  {:ok, Map.put(context, :session, session)}
end
```

**Asserting on visible content (what user sees):**
```elixir
then_ "user sees success message", context do
  context.session |> assert_has(css(".alert", text: "Welcome"))
  :ok
end

then_ "user sees validation error", context do
  context.session |> assert_has(css(".error", text: "is invalid"))
  :ok
end
```

**Asserting element presence/absence:**
```elixir
then_ "the form is displayed", context do
  context.session |> assert_has(css("#registration-form"))
  :ok
end

then_ "error is not shown", context do
  context.session |> refute_has(css(".error"))
  :ok
end
```

**Asserting redirects (current path after action):**
```elixir
then_ "user is redirected to dashboard", context do
  assert current_path(context.session) == "/dashboard"
  :ok
end
```

### Complete Example

```elixir
defmodule MetricFlowSpex.UserRegistrationSpex do
  use SexySpex
  use Wallaby.DSL
  import Wallaby.Query

  import_givens MetricFlowSpex.SharedGivens

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MetricFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end

  spex "User registration" do
    scenario "user registers with valid credentials", context do
      given_ "the registration page is loaded", context do
        session = context.session |> visit("/users/register")
        {:ok, Map.put(context, :session, session)}
      end

      when_ "user submits valid credentials", context do
        session = context.session
          |> fill_in(text_field("Email"), with: "test@example.com")
          |> fill_in(text_field("Password"), with: "SecurePass123!")
          |> click(button("Create account"))
        {:ok, Map.put(context, :session, session)}
      end

      then_ "user sees welcome message", context do
        context.session |> assert_has(css(".alert", text: "Welcome"))
        :ok
      end
    end

    scenario "user sees validation errors for invalid input", context do
      given_ "the registration page is loaded", context do
        session = context.session |> visit("/users/register")
        {:ok, Map.put(context, :session, session)}
      end

      when_ "user submits invalid email", context do
        session = context.session
          |> fill_in(text_field("Email"), with: "invalid")
          |> fill_in(text_field("Password"), with: "short")
          |> click(button("Create account"))
        {:ok, Map.put(context, :session, session)}
      end

      then_ "user sees error messages", context do
        context.session |> assert_has(css(".error", text: "must have the @ sign"))
        context.session |> assert_has(css(".error", text: "should be at least"))
        :ok
      end
    end
  end
end
```


## Shared Givens

Shared givens allow reusable setup steps across specs. The shared givens file is at:
`test/support/shared_givens.ex`

### Current Shared Givens Content

```elixir
defmodule MetricFlowSpex.SharedGivens do
  @moduledoc """
  Shared given steps for BDD specifications.

  Import these givens in your spec files:

      defmodule MetricFlowSpex.FeatureNameSpex do
        use SexySpex
        import_givens MetricFlowSpex.SharedGivens.SharedGivens
        # ...
      end

  Add new shared givens here when you find yourself duplicating setup code
  across multiple specs. Remember: spex files can only access the Web layer,
  so shared givens should set up state through UI interactions, not fixtures.
  """

  use SexySpex.Givens

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint MetricFlowWeb.Endpoint

  given :user_registered_with_password do
    email = "testuser#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    conn = Phoenix.ConnTest.build_conn()
    {:ok, view, _html} = live(conn, "/users/register")

    view
    |> form("#registration_form", user: %{
      email: email,
      password: password,
      account_name: "Test Account"
    })
    |> render_submit()

    # Drain all emails from the mailbox so they don't interfere with later assert_email_sent calls
    Process.sleep(50)
    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end
    drain.(drain)

    {:ok, %{registered_email: email, registered_password: password}}
  end

  given :user_logged_in_as_owner do
    email = "owner#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    # Register through UI
    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form", user: %{
      email: email,
      password: password,
      account_name: "Owner Account"
    })
    |> render_submit()

    # Drain all emails from the mailbox so they don't interfere with later assert_email_sent calls
    Process.sleep(50)
    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end
    drain.(drain)

    # Log in through UI
    login_conn = build_conn()
    {:ok, login_view, _html} = live(login_conn, "/users/log-in")

    login_form =
      form(login_view, "#login_form_password", user: %{
        email: email,
        password: password,
        remember_me: true
      })

    logged_in_conn = submit_form(login_form, login_conn)
    authed_conn = recycle(logged_in_conn)

    {:ok,
     %{
       owner_conn: authed_conn,
       owner_email: email,
       owner_password: password
     }}
  end

  given :owner_with_integrations do
    email = "owner#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    # Register through UI to create a user and account
    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form", user: %{
      email: email,
      password: password,
      account_name: "Owner Account"
    })
    |> render_submit()

    # Drain all emails from the mailbox so they don't interfere with later assert_email_sent calls
    Process.sleep(50)
    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end
    drain.(drain)

    # Look up the created user to insert an integration fixture
    user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
    MetricFlowTest.IntegrationsFixtures.integration_fixture(user)

    # Log in through UI
    login_conn = build_conn()
    {:ok, login_view, _html} = live(login_conn, "/users/log-in")

    login_form =
      form(login_view, "#login_form_password", user: %{
        email: email,
        password: password,
        remember_me: true
      })

    logged_in_conn = submit_form(login_form, login_conn)
    authed_conn = recycle(logged_in_conn)

    {:ok,
     %{
       owner_conn: authed_conn,
       owner_email: email,
       owner_password: password
     }}
  end

  given :second_user_registered do
    email = "member#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form", user: %{
      email: email,
      password: password,
      account_name: "Member Account"
    })
    |> render_submit()

    # Drain all emails from the mailbox so they don't interfere with later assert_email_sent calls
    Process.sleep(50)
    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end
    drain.(drain)

    {:ok, %{second_user_email: email, second_user_password: password}}
  end
end

```

### Using Shared Givens

To use shared givens in your spec file:

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  import_givens MetricFlowSpex.SharedGivens.SharedGivens

  spex "feature" do
    scenario "test case" do          # No context parameter on scenario
      given_ :user_registered        # Shared given - sets up state through UI
      given_ "specific setup", context do  # Inline given takes context when needed
        Map.put(context, :extra, true)
      end
      # ...
    end
  end
end
```

### When to Add Shared Givens

**Only add new shared givens if**:
- You find yourself duplicating the same UI setup code across multiple specs
- The setup is generic enough to be reused (e.g., "user is registered", "user is on dashboard")

**Do NOT add shared givens for**:
- One-off, scenario-specific setup
- Setup that includes criterion-specific data

**Remember**: Shared givens must set up state through the UI (Wallaby browser/ConnTest),
not by calling context functions or fixtures directly.

If you add a new shared given, update the `test/support/shared_givens.ex` file with the new definition.

## Testing Layer Guidelines

**IMPORTANT**: Write specs at the SURFACE layer, not the domain layer.

BDD specs should test user-facing behavior through the UI, not internal function calls.

| Component Type | Testing Approach |
|----------------|------------------|
| LiveView (`*Web.*Live.*`) | `Wallaby` - browser-based testing: navigate, fill in, click, assert |
| Controller (`*Web.*Controller`) | `Phoenix.ConnTest` - HTTP requests and responses |
| Context (domain modules) | Only if explicitly testing pure business logic without UI |
| Schema | Changeset validation tests |

### Surface Testing Principles

- **Test what users SEE and DO** - not internal function calls
- **Assert on HTML content** - text, elements, attributes users interact with
- **Test user interactions** - form submissions, button clicks, navigation
- **Assert on flash messages and redirects** - the feedback users receive
- **Avoid calling context functions directly** - go through the UI layer

For `*Web.*` modules, ALWAYS use Wallaby (LiveView) or ConnTest (controllers) to simulate real user interactions.

## Spex DSL Syntax Guide

Spex is a BDD framework for Elixir that uses Given/When/Then steps to describe behavior.

### Key Points

1. **Module naming**: Use `MetricFlowSpex.FeatureNameSpex` convention (all specs under `MetricFlowSpex` boundary)
2. **import_givens**: Import shared given definitions from `MetricFlowSpex.SharedGivens`
3. **spex macro**: Wraps all scenarios for a feature
4. **scenario macro**: Defines a specific test case. Context is implicitly available inside - do NOT pass it as a parameter.
5. **given_/when_/then_ macros**: Define steps. Pass `context` when you need to read or update it.

### Context Availability

- `context` is automatically available inside every scenario (from ExUnit setup)
- Steps that need context take it as a parameter: `given_ "desc", context do`
- Steps that don't need context omit it: `then_ "desc" do`
- If a step takes context but doesn't use it, prefix with underscore: `given_ "desc", _context do`

### Step Return Values

**IMPORTANT**: Steps must return specific values to update context correctly:

- `given_` and `when_` steps that update context: Return `{:ok, updated_map}`
- `given_` and `when_` steps that don't update context: Return `:ok`
- `then_` steps: Return `:ok` after assertions
- Returning a bare map raises `ArgumentError` — always wrap in `{:ok, map}`

```elixir
given_ "user navigates to registration", context do
  session = context.session |> visit("/users/register")
  {:ok, Map.put(context, :session, session)}
end

then_ "user sees welcome message", context do
  context.session |> assert_has(css(".alert", text: "Welcome"))
  :ok
end
```

## Instructions

**IMPORTANT: Write ONE spec file at a time, then STOP and wait for validation feedback.**

Do not write multiple spec files in a single pass. Write one, let it be validated, fix any
issues, then proceed to the next. This prevents cascading errors across multiple files.

For each criterion:
1. Create the spec file at the path specified
2. **All spec modules must be under the `MetricFlowSpex` namespace** (e.g., `MetricFlowSpex.UserRegistrationSpex`)
3. **Write actual test implementations** - NO TODOs or placeholder comments
4. **Surface layer ONLY** - Do NOT call context functions, fixtures, or factories. All state setup must go through the UI.
5. Use the testing patterns shown above for liveview components
6. Run `mix compile` to verify the spec compiles correctly
7. **STOP and wait for validation** before writing the next spec
8. Fix any validation errors before proceeding

Reference files:
- Boundary definition: `test/spex/metric_flow_spex.ex`
- Shared givens: `test/support/shared_givens.ex`
