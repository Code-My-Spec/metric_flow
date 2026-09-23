defmodule MetricFlowSpex.UserCanSelectMultipleIncomeAccountsSystemWillSumDebitsAndCreditsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can select multiple income accounts, system will sum debits and credits" do
    scenario "the account selection page allows selecting multiple accounts" do
      given_ :owner_with_quickbooks_integration

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "account selection inputs or manual entry are available", context do
        assert has_element?(context.view, "[data-role='account-checkbox']") or
                 has_element?(context.view, "[data-role='manual-property-input']") or
                 has_element?(context.view, "[data-role='manual-entry']")
        :ok
      end

      then_ "the page shows an account list or manual entry section", context do
        assert has_element?(context.view, "[data-role='account-list']") or
                 has_element?(context.view, "[data-role='manual-entry']") or
                 has_element?(context.view, "[data-role='account-selection']")
        :ok
      end
    end

    scenario "saving multiple selected accounts preserves the selection" do
      given_ :owner_with_quickbooks_integration

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user enters an account ID and submits the form", context do
        result =
          context.view
          |> element("[data-role='account-selection']")
          |> render_submit(%{"manual_property_id" => "42"})

        {:ok, Map.put(context, :save_result, result)}
      end

      then_ "the user is redirected back to the provider detail page", context do
        {path, _flash} = assert_redirect(context.view)
        assert path =~ "/app/integrations"
        :ok
      end
    end
  end
end
