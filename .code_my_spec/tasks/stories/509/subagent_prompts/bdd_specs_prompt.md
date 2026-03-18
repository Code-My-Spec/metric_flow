# Write BDD Specifications for Story

Create BDD specification files using the Spex DSL for the following story and its acceptance criteria.

## Story Context

**ID**: 509
**Title**: Sync Google Analytics 4 Data
**Description**: As a client user, I want my Google Analytics 4 property data to be synced daily so that website traffic and engagement metrics are available alongside my marketing spend and revenue data for correlation analysis.
**Priority**: 13

## Component Under Test

**Module**: `MetricFlowWeb.IntegrationLive.SyncHistory`
**Type**: liveview

## Acceptance Criteria

### Criterion 4746: System fetches GA4 data using the Google Analytics Data API v1 (runReport endpoint), not the Universal Analytics API

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4746_system_fetches_ga4_data_using_the_google_analytics_data_api_v1_runreport_endpoint_not_the_universal_analytics_api_spex.exs`

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


### Criterion 4747: Data is fetched per GA4 property selected during OAuth connection

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4747_data_is_fetched_per_ga4_property_selected_during_oauth_connection_spex.exs`

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


### Criterion 4748: System syncs the following GA4 metrics as core daily values: activeUsers, active7DayUsers, active28DayUsers, newUsers, engagedSessions, sessions, userEngagementDuration, screenPageViews, eventCount, keyEvents, scrolledUsers

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4748_system_syncs_the_following_ga4_metrics_as_core_daily_values_activeusers_active7dayusers_active28dayusers_newusers_engagedsessions_sessions_userengagementduration_screenpageviews_eventcount_keyevents_scrolledusers_spex.exs`

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


### Criterion 4750: Each metric is stored as a daily time-series value keyed to the property and client account

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4750_each_metric_is_stored_as_a_daily_time-series_value_keyed_to_the_property_and_client_account_spex.exs`

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


### Criterion 4751: On first sync, system backfills up to 548 days of historical GA4 data (approximately 18 months); on subsequent syncs, fetches from the day after the last stored metric date

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4751_on_first_sync_system_backfills_up_to_548_days_of_historical_ga4_data_approximately_18_months_on_subsequent_syncs_fetches_from_the_day_after_the_last_stored_metric_date_spex.exs`

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


### Criterion 4752: Subsequent daily syncs fetch data for yesterday only (avoids incomplete current-day data)

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4752_subsequent_daily_syncs_fetch_data_for_yesterday_only_avoids_incomplete_current-day_data_spex.exs`

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


### Criterion 4753: Sampled data responses are detected and flagged — system logs a warning and stores data with a sampling caveat

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4753_sampled_data_responses_are_detected_and_flagged_system_logs_a_warning_and_stores_data_with_a_sampling_caveat_spex.exs`

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


### Criterion 4754: System handles GA4 API quota limits with exponential backoff and retry (default quota: 10 requests/second/project)

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4754_system_handles_ga4_api_quota_limits_with_exponential_backoff_and_retry_default_quota_10_requestssecondproject_spex.exs`

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


### Criterion 4755: If GA4 API returns no data for a day (e.g., property had no traffic), a zero-value record is stored rather than a gap

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4755_if_ga4_api_returns_no_data_for_a_day_eg_property_had_no_traffic_a_zero-value_record_is_stored_rather_than_a_gap_spex.exs`

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


### Criterion 4756: GA4 metrics are mapped to canonical metric names in the cross-platform metric taxonomy (e.g., GA4 'sessions' maps to canonical 'sessions')

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4756_ga4_metrics_are_mapped_to_canonical_metric_names_in_the_cross-platform_metric_taxonomy_eg_ga4_sessions_maps_to_canonical_sessions_spex.exs`

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


### Criterion 4757: GA4-specific metrics that have no canonical equivalent are stored as platform-specific metrics labeled 'Google Analytics: [metric name]'

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4757_ga4-specific_metrics_that_have_no_canonical_equivalent_are_stored_as_platform-specific_metrics_labeled_google_analytics_metric_name_spex.exs`

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


### Criterion 4758: Sync failures for a GA4 property are logged with the API error response and surfaced in Sync Status and History

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4758_sync_failures_for_a_ga4_property_are_logged_with_the_api_error_response_and_surfaced_in_sync_status_and_history_spex.exs`

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


### Criterion 4759: Data fetched is scoped to the date range dimension only — no other dimensions (e.g., source/medium) are stored at this stage

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4759_data_fetched_is_scoped_to_the_date_range_dimension_only_no_other_dimensions_eg_sourcemedium_are_stored_at_this_stage_spex.exs`

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


### Criterion 4760: Because GA4's runReport endpoint has a 10-metric limit per request, metrics are fetched in chunks of 10 and results are merged by date before storage; the final stored data is identical to a single-request response would be

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4760_because_ga4s_runreport_endpoint_has_a_10-metric_limit_per_request_metrics_are_fetched_in_chunks_of_10_and_results_are_merged_by_date_before_storage_the_final_stored_data_is_identical_to_a_single-request_response_would_be_spex.exs`

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


### Criterion 4761: Because GA4's runReport endpoint has a 10-metric limit per request, metrics are fetched in chunks of 10 and results are merged by date before storage; the final stored data is equivalent to what a single-request response would contain

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/509_sync_google_analytics_4_data/criterion_4761_because_ga4s_runreport_endpoint_has_a_10-metric_limit_per_request_metrics_are_fetched_in_chunks_of_10_and_results_are_merged_by_date_before_storage_the_final_stored_data_is_equivalent_to_what_a_single-request_response_would_contain_spex.exs`

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
