defmodule MetricFlowSpex.AfterSuccessfulAuthenticationUserCanSelectWhichIncomeAccountsToTrackSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "After successful authentication, user can select which income accounts to track" do
    scenario "the account selection page displays available income accounts" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows an account selection interface", context do
        assert has_element?(context.view, "[data-role='account-selection']")
        :ok
      end

      then_ "the page title references QuickBooks", context do
        html = render(context.view)
        assert html =~ "QuickBooks"
        :ok
      end
    end

    scenario "the account selection page shows a list of selectable accounts" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays checkboxes for account selection", context do
        assert has_element?(context.view, "[data-role='account-checkbox']")
        :ok
      end
    end

    scenario "the user can save their account selection" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the save selection button", context do
        result =
          context.view
          |> element("[data-role='save-selection']")
          |> render_click()

        {:ok, Map.put(context, :save_result, result)}
      end

      then_ "the user is redirected to the integrations list", context do
        assert_redirect(context.view, "/integrations")
        :ok
      end
    end
  end
end
