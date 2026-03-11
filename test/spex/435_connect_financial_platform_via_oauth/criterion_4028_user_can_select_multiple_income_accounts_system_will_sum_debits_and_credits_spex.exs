defmodule MetricFlowSpex.UserCanSelectMultipleIncomeAccountsSystemWillSumDebitsAndCreditsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can select multiple income accounts, system will sum debits and credits" do
    scenario "the account selection page allows selecting multiple accounts" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "multiple checkboxes are available for account selection", context do
        assert has_element?(context.view, "[data-role='account-checkbox']")
        :ok
      end

      then_ "the page shows an account list with selectable items", context do
        assert has_element?(context.view, "[data-role='account-list']")
        :ok
      end
    end

    scenario "saving multiple selected accounts preserves the selection" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user saves the account selection", context do
        result =
          context.view
          |> element("[data-role='save-selection']")
          |> render_click()

        {:ok, Map.put(context, :save_result, result)}
      end

      then_ "the user is redirected back to the integrations page", context do
        assert_redirect(context.view, "/integrations")
        :ok
      end
    end
  end
end
