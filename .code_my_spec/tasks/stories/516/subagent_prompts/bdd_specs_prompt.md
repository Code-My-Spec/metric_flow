# Write BDD Specifications for Story

Create BDD specification files using the Spex DSL for the following story and its acceptance criteria.

## Story Context

**ID**: 516
**Title**: Sync Google Search Console Data
**Description**: As a client user, I want my Google Search Console data synced daily so that organic search performance metrics are available alongside my paid advertising and revenue data for correlation analysis.
**Priority**: 14

## Component Under Test

**Module**: `MetricFlowWeb.IntegrationLive.SyncHistory`
**Type**: liveview

## Acceptance Criteria

### Criterion 4806: System fetches data using the Google Search Console API (webmasters v3, searchanalytics.query endpoint) authenticated via Google OAuth2 with webmasters.readonly scope — reuses the same Google OAuth token as GA4 and Google Ads

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4806_system_fetches_data_using_the_google_search_console_api_webmasters_v3_searchanalyticsquery_endpoint_authenticated_via_google_oauth2_with_webmastersreadonly_scope_reuses_the_same_google_oauth_token_as_ga4_and_google_ads_spex.exs`

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


### Criterion 4807: Data is fetched per site URL (googleConsoleSiteUrl) configured per customer in config.json; customers without a site URL are skipped

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4807_data_is_fetched_per_site_url_googleconsolesiteurl_configured_per_customer_in_configjson_customers_without_a_site_url_are_skipped_spex.exs`

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


### Criterion 4808: Two API calls are made per sync: one with no dimensions (overall aggregate for the period) and one with dimensions: ['date'] (daily breakdown)

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4808_two_api_calls_are_made_per_sync_one_with_no_dimensions_overall_aggregate_for_the_period_and_one_with_dimensions_date_daily_breakdown_spex.exs`

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


### Criterion 4809: Core metrics synced per day: clicks, impressions, ctr (click-through rate), position (average search position)

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4809_core_metrics_synced_per_day_clicks_impressions_ctr_click-through_rate_position_average_search_position_spex.exs`

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


### Criterion 4810: Daily metrics use the date key from the API response; overall/aggregate metrics have no date key and default to current date — KNOWN BUG: overall metrics should not be stored without a valid date anchor

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4810_daily_metrics_use_the_date_key_from_the_api_response_overallaggregate_metrics_have_no_date_key_and_default_to_current_date_known_bug_overall_metrics_should_not_be_stored_without_a_valid_date_anchor_spex.exs`

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


### Criterion 4811: Metrics are stored via upsert keyed on (customerName, platformExternalId, externalLocationId, metricKey, date) — re-runs are safe and idempotent, unlike the other ad platform integrations which use insert

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4811_metrics_are_stored_via_upsert_keyed_on_customername_platformexternalid_externallocationid_metrickey_date_re-runs_are_safe_and_idempotent_unlike_the_other_ad_platform_integrations_which_use_insert_spex.exs`

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


### Criterion 4812: ARCHITECTURAL NOTE: Unlike other integrations, the fetcher writes directly to the database internally rather than returning raw data to a separate formatter/index layer — this is inconsistent with the rest of the integration architecture and should be refactored

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4812_architectural_note_unlike_other_integrations_the_fetcher_writes_directly_to_the_database_internally_rather_than_returning_raw_data_to_a_separate_formatterindex_layer_this_is_inconsistent_with_the_rest_of_the_integration_architecture_and_should_be_refactored_spex.exs`

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


### Criterion 4813: Dimension-scoped metric keys are formatted as '{metricKey}_{dimension}' (e.g., 'clicks_date'); overall metric keys are unscoped (e.g., 'clicks')

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4813_dimension-scoped_metric_keys_are_formatted_as_metrickey_dimension_eg_clicks_date_overall_metric_keys_are_unscoped_eg_clicks_spex.exs`

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


### Criterion 4814: Token expiry is checked before each API call; if expired, a refresh is attempted using the stored refresh token; if refresh fails, the existing token is used and the API call proceeds anyway

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4814_token_expiry_is_checked_before_each_api_call_if_expired_a_refresh_is_attempted_using_the_stored_refresh_token_if_refresh_fails_the_existing_token_is_used_and_the_api_call_proceeds_anyway_spex.exs`

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


### Criterion 4815: On first sync, backfill window is determined by the service layer (consistent with other integrations at 548 days); subsequent syncs fetch from day after last stored metric date

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4815_on_first_sync_backfill_window_is_determined_by_the_service_layer_consistent_with_other_integrations_at_548_days_subsequent_syncs_fetch_from_day_after_last_stored_metric_date_spex.exs`

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


### Criterion 4816: Sync failures are logged with full error context including siteUrl, customerName, and dateRange and surfaced in Sync Status and History

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/516_sync_google_search_console_data/criterion_4816_sync_failures_are_logged_with_full_error_context_including_siteurl_customername_and_daterange_and_surfaced_in_sync_status_and_history_spex.exs`

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
