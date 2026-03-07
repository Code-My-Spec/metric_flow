# Write BDD Specifications for Story

Create BDD specification files using the Spex DSL for the following story and its acceptance criteria.

## Story Context

**ID**: 428
**Title**: Client Invites Agency or Individual User Access
**Description**: As a client account owner, I want to invite agencies or individual users to access my account so that they can help manage my marketing data and reporting.
**Priority**: 23

## Component Under Test

**Module**: `MetricFlowWeb.InvitationLive.Send`
**Type**: liveview

## Acceptance Criteria

### Criterion 3969: Client can send email invitation to any email address (agency or individual)

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/428_client_invites_agency_or_individual_user_access/criterion_3969_client_can_send_email_invitation_to_any_email_address_agency_or_individual_spex.exs`

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


### Criterion 3970: Invitation email contains secure link with expiration time of 7 days

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/428_client_invites_agency_or_individual_user_access/criterion_3970_invitation_email_contains_secure_link_with_expiration_time_of_7_days_spex.exs`

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


### Criterion 3971: Invitee receives invitation in their email inbox

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/428_client_invites_agency_or_individual_user_access/criterion_3971_invitee_receives_invitation_in_their_email_inbox_spex.exs`

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


### Criterion 3972: Invitation includes client account name and access level being granted

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/428_client_invites_agency_or_individual_user_access/criterion_3972_invitation_includes_client_account_name_and_access_level_being_granted_spex.exs`

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


### Criterion 3973: Client can specify access level in invitation: read-only, account manager, or admin

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/428_client_invites_agency_or_individual_user_access/criterion_3973_client_can_specify_access_level_in_invitation_read-only_account_manager_or_admin_spex.exs`

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


### Criterion 3974: Invitation link is single-use and invalidated after acceptance or expiration

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/428_client_invites_agency_or_individual_user_access/criterion_3974_invitation_link_is_single-use_and_invalidated_after_acceptance_or_expiration_spex.exs`

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


### Criterion 3975: Client can view pending invitations and cancel them before acceptance

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/428_client_invites_agency_or_individual_user_access/criterion_3975_client_can_view_pending_invitations_and_cancel_them_before_acceptance_spex.exs`

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


### Criterion 3976: Client can invite multiple agencies or users with different access levels

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/428_client_invites_agency_or_individual_user_access/criterion_3976_client_can_invite_multiple_agencies_or_users_with_different_access_levels_spex.exs`

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
