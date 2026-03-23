defmodule MetricFlowSpex.UserCanUpdateLocationSelectionAtAnyTimeWithoutReAuthenticatingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can update location selection at any time without re-authenticating", fail_on_error_logs: false do
    scenario "user with existing google_business integration can access location selection" do
      given_ :user_logged_in_as_owner

      given_ "the user has a google_business integration", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :google_business})
        {:ok, context}
      end

      given_ "the user navigates to the google_business accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a location selection interface without being prompted to re-authenticate", context do
        html = render(context.view)
        assert html =~ "location" or html =~ "Location" or
                 html =~ "account" or html =~ "Account" or
                 html =~ "select" or html =~ "Select"
        :ok
      end

      then_ "the user does not see a re-authenticate prompt", context do
        html = render(context.view)
        refute html =~ "Re-authenticate"
        refute html =~ "re-authenticate"
        :ok
      end
    end

    scenario "user can navigate back to accounts page without triggering OAuth flow" do
      given_ :user_logged_in_as_owner

      given_ "the user has a google_business integration", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :google_business})
        {:ok, context}
      end

      given_ "the user visits the google_business accounts page a second time", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page does not redirect to an OAuth URL", context do
        html = render(context.view)
        refute html =~ "accounts.google.com"
        refute html =~ "oauth"
        :ok
      end

      then_ "the page provides a mechanism to update the location selection", context do
        assert has_element?(context.view, "input[type='checkbox']") or
                 has_element?(context.view, "input[type='radio']") or
                 has_element?(context.view, "[data-role='location-checkbox']") or
                 has_element?(context.view, "[data-role='account-selection']") or
                 has_element?(context.view, "[data-role='location-selection']")
        :ok
      end
    end

    scenario "location selection page does not prompt re-connection to google_business" do
      given_ :user_logged_in_as_owner

      given_ "the user has a google_business integration", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :google_business})
        {:ok, context}
      end

      given_ "the user navigates to the google_business accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google_business/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page does not tell the user to re-connect", context do
        html = render(context.view)
        refute html =~ "Re-connect"
        refute html =~ "re-connect"
        :ok
      end

      then_ "the page shows location or account content for selection", context do
        html = render(context.view)
        assert html =~ "location" or html =~ "Location" or
                 html =~ "business" or html =~ "Business" or
                 html =~ "account" or html =~ "Account"
        :ok
      end
    end
  end
end
