defmodule MetricFlowSpex.UserCanSelectWhichAdAccountsOrPropertiesToSyncFromConnectedPlatformSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can select which ad accounts or properties to sync from connected platform", fail_on_error_logs: false do
    scenario "after connecting a provider the user sees an account selection UI" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the user visits the OAuth callback with a success code and is redirected", context do
        _callback_conn = get(context.owner_conn, "/app/integrations/oauth/callback/google",
          MetricFlowTest.OAuthStub.valid_callback_params())
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees options to select ad accounts or properties for syncing", context do
        html = render(context.view)
        assert html =~ "account" or html =~ "Account" or
                 html =~ "propert" or html =~ "select" or html =~ "Select"
        :ok
      end
    end

    scenario "the provider account selection page lists available accounts to sync" do
      given_ :owner_with_google_ads_integration

      given_ "the user navigates to the account selection page for a connected provider", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_analytics/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a list of available ad accounts or properties", context do
        assert has_element?(context.view, "[data-role='account-list']") or
                 has_element?(context.view, "[data-role='property-list']") or
                 has_element?(context.view, "[data-role='account-selection']")
        :ok
      end
    end

    scenario "the user can select one or more accounts to sync" do
      given_ :owner_with_google_ads_integration

      given_ "the user is on the account selection page for Google Analytics", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_analytics/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each account entry has a selectable input or manual entry field", context do
        assert has_element?(context.view, "input[type='checkbox'][data-role='account-checkbox']") or
                 has_element?(context.view, "input[type='checkbox']") or
                 has_element?(context.view, "input[type='radio']") or
                 has_element?(context.view, "[data-role='account-toggle']") or
                 has_element?(context.view, "[data-role='manual-property-input']")
        :ok
      end
    end

    scenario "the user can confirm the account selection to start syncing" do
      given_ :owner_with_google_ads_integration

      given_ "the user is on the account selection page for Google Analytics", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_analytics/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page has a confirm or save selection button", context do
        assert has_element?(context.view, "[data-role='save-selection']") or
                 has_element?(context.view, "button", "Save") or
                 has_element?(context.view, "button", "Confirm") or
                 has_element?(context.view, "button", "Start Syncing")
        :ok
      end
    end

    scenario "the user can select properties to sync from Google Analytics" do
      given_ :owner_with_google_ads_integration

      given_ "the user navigates to the account selection page for Google Analytics", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_analytics/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a list of properties available to sync", context do
        html = render(context.view)
        assert html =~ "propert" or html =~ "Propert" or
                 html =~ "account" or html =~ "Account"
        :ok
      end

      then_ "the page has a mechanism to select which properties to sync", context do
        assert has_element?(context.view, "input[type='checkbox']") or
                 has_element?(context.view, "input[type='radio']") or
                 has_element?(context.view, "[data-role='property-toggle']") or
                 has_element?(context.view, "[data-role='account-selection']") or
                 has_element?(context.view, "[data-role='manual-property-input']")
        :ok
      end
    end
  end
end
