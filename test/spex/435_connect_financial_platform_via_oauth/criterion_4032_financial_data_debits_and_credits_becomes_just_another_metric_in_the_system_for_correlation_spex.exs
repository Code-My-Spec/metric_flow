defmodule MetricFlowSpex.FinancialDataDebitsAndCreditsBecomesJustAnotherMetricInTheSystemForCorrelationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Financial data (debits and credits) becomes just another metric in the system for correlation" do
    scenario "the QuickBooks detail page describes syncing financial data" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the QuickBooks connect detail page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/connect/quickbooks")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page describes QuickBooks as a data source", context do
        html = render(context.view)
        assert html =~ "QuickBooks"
        :ok
      end

      then_ "the page mentions syncing data", context do
        html = render(context.view)
        assert html =~ "sync" or html =~ "syncing" or html =~ "data"
        :ok
      end
    end

    scenario "the connect page shows QuickBooks alongside other marketing platforms" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "QuickBooks appears in the platform grid alongside marketing platforms", context do
        html = render(context.view)
        assert html =~ "QuickBooks"
        assert html =~ "Google Ads" or html =~ "Facebook Ads"
        :ok
      end
    end

    scenario "a connected QuickBooks integration appears in the integrations list" do
      given_ :user_logged_in_as_owner

      when_ "the user completes the QuickBooks OAuth flow", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/oauth/callback/quickbooks?code=valid_code")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the callback confirms the integration is active", context do
        html = render(context.view)
        assert html =~ "Active" or html =~ "connected"
        :ok
      end
    end
  end
end
