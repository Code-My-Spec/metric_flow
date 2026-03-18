# Write BDD Specifications for Story

Create BDD specification files using the Spex DSL for the following story and its acceptance criteria.

## Story Context

**ID**: 518
**Title**: Sync QuickBooks Account Transaction Data
**Description**: As a client user, I want my QuickBooks income account data synced daily so that credit transactions (money coming into the business) are available as a metric for correlation analysis against my marketing activity.
**Priority**: 19

## Component Under Test

**Module**: `MetricFlowWeb.IntegrationLive.SyncHistory`
**Type**: liveview

## Acceptance Criteria

### Criterion 4828: System connects to QuickBooks via the OAuth token established in the Connect Financial Platform via OAuth story (435) — no separate auth flow

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4828_system_connects_to_quickbooks_via_the_oauth_token_established_in_the_connect_financial_platform_via_oauth_story_435_no_separate_auth_flow_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4829: Data is fetched per income account selected by the user during OAuth connection setup; multiple selected accounts are each synced independently

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4829_data_is_fetched_per_income_account_selected_by_the_user_during_oauth_connection_setup_multiple_selected_accounts_are_each_synced_independently_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4830: For each account, the system fetches debit and credit transaction totals aggregated by day using the QuickBooks Reports or Transactions API

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4830_for_each_account_the_system_fetches_debit_and_credit_transaction_totals_aggregated_by_day_using_the_quickbooks_reports_or_transactions_api_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4831: Credits (money in) are stored as the primary metric — this represents revenue flowing into the account and is the target variable for correlation analysis

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4831_credits_money_in_are_stored_as_the_primary_metric_this_represents_revenue_flowing_into_the_account_and_is_the_target_variable_for_correlation_analysis_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4832: Debits (money out) are also stored as a separate metric so spend patterns can optionally be correlated as well

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4832_debits_money_out_are_also_stored_as_a_separate_metric_so_spend_patterns_can_optionally_be_correlated_as_well_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4833: Each metric is stored as a daily aggregate value — individual transactions are not stored, only the sum of credits and sum of debits per account per day

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4833_each_metric_is_stored_as_a_daily_aggregate_value_individual_transactions_are_not_stored_only_the_sum_of_credits_and_sum_of_debits_per_account_per_day_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4834: Metric keys are: QUICKBOOKS_ACCOUNT_DAILY_CREDITS and QUICKBOOKS_ACCOUNT_DAILY_DEBITS

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4834_metric_keys_are_quickbooks_account_daily_credits_and_quickbooks_account_daily_debits_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4835: platformExternalId is set to the QuickBooks account ID; externalLocationId is null (financial data has no location concept)

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4835_platformexternalid_is_set_to_the_quickbooks_account_id_externallocationid_is_null_financial_data_has_no_location_concept_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4836: On first sync, system backfills up to 548 days of historical data; subsequent syncs fetch from the day after the last stored metric date

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4836_on_first_sync_system_backfills_up_to_548_days_of_historical_data_subsequent_syncs_fetch_from_the_day_after_the_last_stored_metric_date_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4837: Days with no transactions are stored as zero-value records rather than gaps, to preserve continuity for correlation calculations

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4837_days_with_no_transactions_are_stored_as_zero-value_records_rather_than_gaps_to_preserve_continuity_for_correlation_calculations_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


### Criterion 4838: Sync failures are logged with full error context including accountId, customerName, and dateRange and surfaced in Sync Status and History

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4838_sync_failures_are_logged_with_full_error_context_including_accountid_customername_and_daterange_and_surfaced_in_sync_status_and_history_spex.exs`

**Testing Approach for LiveView (SURFACE LAYER):**
- **Test what users SEE and DO** - not internal function calls
- Use the project's existing `MetricFlowWeb.ConnCase` - do NOT create additional case files
- Use `Phoenix.LiveViewTest` for user interaction testing
- Mount the LiveView with `live/2` - use plain string paths, not `~p` sigils
- Use `form/3` + `render_submit/1` for form submissions
- Use `element/3` + `render_click/1` for button clicks
- Assert on HTML: `render/1 =~ "text"`, `has_element?/2`

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
end
```


## LiveView Testing Guide

This is a LiveView component. **Test at the SURFACE layer** using `Phoenix.LiveViewTest`.

### Key Principles

- **Test what users SEE** - assert on rendered HTML, text content, element presence
- **Test what users DO** - form submissions, button clicks, link navigation
- **DON'T call context functions or fixtures** - all state setup through UI
- **Assert on user feedback** - flash messages, error text, success confirmations

### Required Setup

**IMPORTANT**: Use the project's existing `MetricFlowWeb.ConnCase` module. Do NOT create additional
case files, and do NOT manually set `@endpoint` or `setup do` blocks for conn - `ConnCase`
already provides these.

```elixir
defmodule MetricFlowSpex.FeatureNameSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens
```

**Note:** Use plain strings for paths (e.g., `"/users/register"`) instead of the `~p` sigil.
The `~p` sigil requires importing `Phoenix.VerifiedRoutes` and adds unnecessary dependencies.

### LiveView Testing Patterns

**Mounting the LiveView:**
```elixir
given_ "the registration page is loaded", context do
  {:ok, view, _html} = live(context.conn, "/users/register")
  {:ok, Map.put(context, :view, view)}
end
```

**Submitting forms (most common user action):**
```elixir
when_ "user submits valid credentials", context do
  html = context.view
    |> form("#registration-form", user: %{email: "test@example.com", password: "SecurePass123!"})
    |> render_submit()
  {:ok, Map.put(context, :result_html, html)}
end
```

**Clicking buttons/links:**
```elixir
when_ "user clicks the submit button", context do
  html = context.view |> element("button", "Submit") |> render_click()
  {:ok, Map.put(context, :html, html)}
end
```

**Asserting on visible content (what user sees):**
```elixir
then_ "user sees success message", context do
  assert render(context.view) =~ "Welcome"
  :ok
end

then_ "user sees validation error", context do
  assert render(context.view) =~ "is invalid"
  :ok
end
```

**Asserting element presence:**
```elixir
then_ "the form is displayed", context do
  assert has_element?(context.view, "#registration-form")
  :ok
end
```

**Asserting redirects (after successful actions):**
```elixir
then_ "user is redirected to dashboard", context do
  assert_redirect(context.view, "/dashboard")
  :ok
end
```

### Complete Example

```elixir
defmodule MetricFlowSpex.UserRegistrationSpex do
  use SexySpex
  use MetricFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User registration" do
    scenario "user registers with valid credentials", context do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user submits valid credentials", context do
        html = context.view
          |> form("#registration-form", user: %{email: "test@example.com", password: "SecurePass123!"})
          |> render_submit()
        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "user sees welcome message", context do
        # Assert on what the USER SEES - the rendered HTML
        assert render(context.view) =~ "Welcome"
        :ok
      end
    end

    scenario "user sees validation errors for invalid input", context do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user submits invalid email", context do
        html = context.view
          |> form("#registration-form", user: %{email: "invalid", password: "short"})
          |> render_submit()
        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "user sees error messages", context do
        html = render(context.view)
        assert html =~ "must have the @ sign"
        assert html =~ "should be at least"
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

  given :owner_with_google_ads_integration do
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

    Process.sleep(50)
    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end
    drain.(drain)

    # Create integration fixture
    user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
    MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :google})

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

  given :owner_with_quickbooks_integration do
    email = "owner#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form", user: %{
      email: email,
      password: password,
      account_name: "Owner Account"
    })
    |> render_submit()

    Process.sleep(50)
    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end
    drain.(drain)

    user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
    MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :quickbooks})

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

  given :with_oauth_stub_providers do
    MetricFlowTest.OAuthStub.setup_oauth_providers()
    {:ok, %{oauth_state: MetricFlowTest.OAuthStub.state_token()}}
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

**Remember**: Shared givens must set up state through the UI (LiveViewTest/ConnTest),
not by calling context functions or fixtures directly.

If you add a new shared given, update the `test/support/shared_givens.ex` file with the new definition.

## Testing Layer Guidelines

**IMPORTANT**: Write specs at the SURFACE layer, not the domain layer.

BDD specs should test user-facing behavior through the UI, not internal function calls.

| Component Type | Testing Approach |
|----------------|------------------|
| LiveView (`*Web.*Live.*`) | `Phoenix.LiveViewTest` - mount, render, interact, assert HTML |
| Controller (`*Web.*Controller`) | `Phoenix.ConnTest` - HTTP requests and responses |
| Context (domain modules) | Only if explicitly testing pure business logic without UI |
| Schema | Changeset validation tests |

### Surface Testing Principles

- **Test what users SEE and DO** - not internal function calls
- **Assert on HTML content** - text, elements, attributes users interact with
- **Test user interactions** - form submissions, button clicks, navigation
- **Assert on flash messages and redirects** - the feedback users receive
- **Avoid calling context functions directly** - go through the UI layer

For `*Web.*` modules, ALWAYS use LiveViewTest or ConnTest to simulate real user interactions.

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
  {:ok, view, _html} = live(context.conn, "/users/register")
  {:ok, Map.put(context, :view, view)}
end

then_ "user sees welcome message", context do
  assert render(context.view) =~ "Welcome"
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
