# Write BDD Specifications for Story

Create BDD specification files using the Spex DSL for the following story and its acceptance criteria.

## Story Context

**ID**: 511
**Title**: Sync Facebook Ads Data
**Description**: As a client user, I want my Facebook Ads account data to be synced daily so that advertising spend, reach, and conversion metrics are available alongside my other platform data for correlation analysis.
**Priority**: 15

## Component Under Test

**Module**: `MetricFlowWeb.IntegrationLive.SyncHistory`
**Type**: liveview

## Acceptance Criteria

### Criterion 4774: System fetches data using facebook-nodejs-business-sdk, calling account.getInsights() at account level with time_increment: 1 (daily breakdown)

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4774_system_fetches_data_using_facebook-nodejs-business-sdk_calling_accountgetinsights_at_account_level_with_time_increment_1_daily_breakdown_spex.exs`

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


### Criterion 4775: Data is fetched per facebookAdsAccountId from config; the 'act_' prefix is added by the fetcher at call time, not stored in config

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4775_data_is_fetched_per_facebookadsaccountid_from_config_the_act_prefix_is_added_by_the_fetcher_at_call_time_not_stored_in_config_spex.exs`

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


### Criterion 4776: Authentication uses a dedicated Facebook OAuth flow separate from Google OAuth, requiring FACEBOOK_APP_ID, FACEBOOK_APP_SECRET, and ads_read scope

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4776_authentication_uses_a_dedicated_facebook_oauth_flow_separate_from_google_oauth_requiring_facebook_app_id_facebook_app_secret_and_ads_read_scope_spex.exs`

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


### Criterion 4777: Metrics are fetched at account level only — one row per day; no campaign, adset, or ad segmentation at this stage

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4777_metrics_are_fetched_at_account_level_only_one_row_per_day_no_campaign_adset_or_ad_segmentation_at_this_stage_spex.exs`

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


### Criterion 4778: Core scalar metrics synced daily: impressions, reach, clicks, spend, cpp, unique_clicks, unique_ctr, frequency, cost_per_ad_click, cost_per_conversion

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4778_core_scalar_metrics_synced_daily_impressions_reach_clicks_spend_cpp_unique_clicks_unique_ctr_frequency_cost_per_ad_click_cost_per_conversion_spex.exs`

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


### Criterion 4779: The 'actions' API field is expanded from array into flat keys as 'actions:{action_type}' for: link_click, page_engagement, post_engagement, post_reaction, comment, like, share, video_view, lead, purchase, complete_registration, add_to_cart, checkout

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4779_the_actions_api_field_is_expanded_from_array_into_flat_keys_as_actionsaction_type_for_link_click_page_engagement_post_engagement_post_reaction_comment_like_share_video_view_lead_purchase_complete_registration_add_to_cart_checkout_spex.exs`

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


### Criterion 4780: The 'cost_per_action_type' field is expanded into flat keys as 'cost_per_action_type:{action_type}' for the same action type list

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4780_the_cost_per_action_type_field_is_expanded_into_flat_keys_as_cost_per_action_typeaction_type_for_the_same_action_type_list_spex.exs`

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


### Criterion 4781: Video completion metrics (video_p25/50/75/100_watched_actions) are arrays — only the video_view action_type entry is extracted and stored as a scalar per metric

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4781_video_completion_metrics_video_p255075100_watched_actions_are_arrays_only_the_video_view_action_type_entry_is_extracted_and_stored_as_a_scalar_per_metric_spex.exs`

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


### Criterion 4782: Rows missing date_start are skipped with a warning; non-numeric metric values are skipped silently

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4782_rows_missing_date_start_are_skipped_with_a_warning_non-numeric_metric_values_are_skipped_silently_spex.exs`

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


### Criterion 4783: On first sync, system backfills 180 days of history; subsequent syncs fetch from the day after the last stored metric date

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4783_on_first_sync_system_backfills_180_days_of_history_subsequent_syncs_fetch_from_the_day_after_the_last_stored_metric_date_spex.exs`

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


### Criterion 4784: Sync uses retryWithBackoff with 3 retries and 2-second initial delay; Facebook API errors are extracted from error.response.error

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4784_sync_uses_retrywithbackoff_with_3_retries_and_2-second_initial_delay_facebook_api_errors_are_extracted_from_errorresponseerror_spex.exs`

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


### Criterion 4785: Polly HTTP record/replay is initialized per fetch and stopped in the finally block — testing tool only, must not affect production sync

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4785_polly_http_recordreplay_is_initialized_per_fetch_and_stopped_in_the_finally_block_testing_tool_only_must_not_affect_production_sync_spex.exs`

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


### Criterion 4786: Sync failures are logged with full error details and surfaced in Sync Status and History

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/511_sync_facebook_ads_data/criterion_4786_sync_failures_are_logged_with_full_error_details_and_surfaced_in_sync_status_and_history_spex.exs`

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
