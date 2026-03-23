# Write BDD Specifications for Story

Create BDD specification files using the Spex DSL for the following story and its acceptance criteria.

## Story Context

**ID**: 520
**Title**: Fetch and Select Google Business Profile Locations Across Multiple Accounts
**Description**: As a client user, I want the system to fetch and display all locations across my connected Google Business Profile accounts so that I can select which locations to include in syncing, with full support for customers who have locations spread across multiple GBP accounts.
**Priority**: 42

## Component Under Test

**Module**: `MetricFlowWeb.IntegrationLive.Connect`
**Type**: liveview

## Acceptance Criteria

### Criterion 4854: System fetches all locations across all configured googleBusinessAccountIds (plural) — iterates over the array and calls accounts/{accountId}/locations for each

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4854_system_fetches_all_locations_across_all_configured_googlebusinessaccountids_plural_iterates_over_the_array_and_calls_accountsaccountidlocations_for_each_spex.exs`

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


### Criterion 4855: Locations are fetched using the Google Business Profile API v1 (mybusinessbusinessinformation or mybusiness v4) with fields: name, title, storeCode, storefrontAddress, websiteUri, regularHours, primaryCategory

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4855_locations_are_fetched_using_the_google_business_profile_api_v1_mybusinessbusinessinformation_or_mybusiness_v4_with_fields_name_title_storecode_storefrontaddress_websiteuri_regularhours_primarycategory_spex.exs`

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


### Criterion 4856: Pagination is handled — system follows nextPageToken until all locations are retrieved for each account

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4856_pagination_is_handled_system_follows_nextpagetoken_until_all_locations_are_retrieved_for_each_account_spex.exs`

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


### Criterion 4857: All locations from all accounts are merged into a single flat list for display and selection

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4857_all_locations_from_all_accounts_are_merged_into_a_single_flat_list_for_display_and_selection_spex.exs`

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


### Criterion 4858: User is presented with the full location list and can select which locations to include in syncing (includedLocations config)

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4858_user_is_presented_with_the_full_location_list_and_can_select_which_locations_to_include_in_syncing_includedlocations_config_spex.exs`

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


### Criterion 4859: Each location row shows: account name (for disambiguation), location name/title, store code if present, and address

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4859_each_location_row_shows_account_name_for_disambiguation_location_nametitle_store_code_if_present_and_address_spex.exs`

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


### Criterion 4860: Selected location IDs are stored in customerConfig.includedLocations as an array, prefixed with their accountId for unambiguous reference across multiple accounts

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4860_selected_location_ids_are_stored_in_customerconfigincludedlocations_as_an_array_prefixed_with_their_accountid_for_unambiguous_reference_across_multiple_accounts_spex.exs`

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


### Criterion 4861: User can update location selection at any time without re-authenticating

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4861_user_can_update_location_selection_at_any_time_without_re-authenticating_spex.exs`

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


### Criterion 4862: If a location disappears from the API (e.g. deleted or access revoked), it is flagged in the UI rather than silently removed from sync config

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4862_if_a_location_disappears_from_the_api_eg_deleted_or_access_revoked_it_is_flagged_in_the_ui_rather_than_silently_removed_from_sync_config_spex.exs`

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


### Criterion 4863: Sync jobs for reviews (story 513) and performance metrics (story 517) are updated to iterate over all accounts in googleBusinessAccountIds — not just a single googleBusinessAccountId

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4863_sync_jobs_for_reviews_story_513_and_performance_metrics_story_517_are_updated_to_iterate_over_all_accounts_in_googlebusinessaccountids_not_just_a_single_googlebusinessaccountid_spex.exs`

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


### Criterion 4864: Backfill behavior for newly added locations matches existing behavior: 548 days on first sync

**Status**: ❌ MISSING
**Expected File Path**: `test/spex/520_fetch_and_select_google_business_profile_locations_across_multiple_accounts/criterion_4864_backfill_behavior_for_newly_added_locations_matches_existing_behavior_548_days_on_first_sync_spex.exs`

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
    MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :google_analytics})

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

  given :with_ai_stubs do
    MetricFlowTest.AiStub.setup_ai_stubs()
    {:ok, %{}}
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
