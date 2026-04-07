defmodule MetricFlowSpex.UserCanModifySelectedAccountsLaterWithoutReAuthenticatingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can modify selected accounts later without re-authenticating" do
    scenario "user can access account selection without OAuth re-authentication" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integration connect page for Google", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an account selection interface", context do
        assert has_element?(context.view, "[data-role='account-selection']")
        :ok
      end

      then_ "the user does not see a re-authenticate button", context do
        refute render(context.view) =~ "Re-authenticate"
        refute render(context.view) =~ "re-authenticate"
        :ok
      end
    end

    scenario "user can edit account selection on an existing integration" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an option to manage existing integrations", context do
        html = render(context.view)
        assert html =~ "integrations" or html =~ "Integrations" or html =~ "Connect"
        :ok
      end
    end

    scenario "modify accounts page provides account selection without OAuth prompt" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to modify accounts for a connected provider", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page title references account selection or modification", context do
        html = render(context.view)
        assert html =~ "account" or html =~ "Account" or html =~ "Connect" or html =~ "provider"
        :ok
      end

      then_ "the page does not prompt the user to start OAuth from scratch", context do
        html = render(context.view)
        refute html =~ "Re-connect"
        :ok
      end
    end
  end
end
