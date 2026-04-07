defmodule MetricFlowSpex.UserCanModifySelectedAccountsWithoutReAuthenticatingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can modify selected accounts without re-authenticating" do
    scenario "the integrations page offers an edit action for an existing integration" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a button or link to edit the account selection for each integration", context do
        assert has_element?(context.view, "[data-role='edit-integration-accounts']")
        :ok
      end
    end

    scenario "clicking edit integration accounts opens a selection page without prompting OAuth" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the edit accounts page for an existing integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/google/accounts/edit")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the account selection page is accessible without OAuth prompts", context do
        assert has_element?(context.view, "[data-role='account-selection']")
        :ok
      end

      then_ "the page does not contain a re-authenticate button", context do
        refute has_element?(context.view, "[data-role='re-authenticate-button']")
        :ok
      end
    end

    scenario "user can save a modified account selection without re-authenticating" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the edit accounts page for an existing integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/google/accounts/edit")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page has a save button to apply changes to the account selection", context do
        assert has_element?(context.view, "[data-role='save-account-selection']")
        :ok
      end

      then_ "the page does not redirect the user to an external OAuth provider", context do
        refute render(context.view) =~ "accounts.google.com"
        :ok
      end
    end

    scenario "the edit accounts page shows the currently selected accounts pre-checked" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the edit accounts page for an existing integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/google/accounts/edit")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the account list has checkboxes for selecting accounts", context do
        assert has_element?(context.view, "input[type='checkbox'][data-role='account-checkbox']")
        :ok
      end
    end
  end
end
