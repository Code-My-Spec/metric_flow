defmodule MetricFlowSpex.AfterSuccessfulAuthenticationUserCanSelectWhichIncomeAccountsToTrackSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "After successful authentication, user can select which income accounts to track" do
    scenario "the account selection page displays available income accounts" do
      given_ :owner_with_quickbooks_integration

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/quickbooks/accounts")

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
      given_ :owner_with_quickbooks_integration

      given_ "the user navigates to the QuickBooks account selection page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays account selection inputs or manual entry", context do
        assert has_element?(context.view, "[data-role='account-checkbox']") or
                 has_element?(context.view, "[data-role='manual-property-input']") or
                 has_element?(context.view, "[data-role='manual-entry']")
        :ok
      end
    end

    scenario "the user can save their account selection" do
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

      then_ "the user is redirected to the provider detail page", context do
        {path, _flash} = assert_redirect(context.view)
        assert path =~ "/app/integrations"
        :ok
      end
    end
  end
end
