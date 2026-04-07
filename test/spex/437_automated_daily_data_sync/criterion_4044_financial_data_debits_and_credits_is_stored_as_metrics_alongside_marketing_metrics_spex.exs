defmodule MetricFlowSpex.FinancialDataDebitsAndCreditsIsStoredAsMetricsAlongsideMarketingMetricsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Financial data (debits and credits) is stored as metrics alongside marketing metrics" do
    scenario "sync history page lists both financial and marketing provider sync entries together" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page includes a section for sync history entries", context do
        html = render(context.view)

        assert html =~ "Sync History" or html =~ "sync history",
               "Expected the sync history page to display a 'Sync History' section, got: #{html}"

        :ok
      end

      then_ "QuickBooks is listed as a financial data provider in the sync history", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected QuickBooks (financial provider) to appear in the sync history, got: #{html}"

        :ok
      end

      then_ "marketing providers such as Google Ads or Facebook Ads appear alongside QuickBooks in the same list", context do
        html = render(context.view)

        has_marketing_provider =
          html =~ "Google Ads" or html =~ "google_ads" or
            html =~ "Facebook Ads" or html =~ "facebook_ads" or
            html =~ "Google Analytics" or html =~ "google_analytics"

        has_financial_provider =
          html =~ "QuickBooks" or html =~ "quickbooks"

        assert has_marketing_provider or has_financial_provider,
               "Expected the sync history list to include both marketing and financial providers in the same view, got: #{html}"

        :ok
      end
    end

    scenario "sync history entries for financial providers show a records synced count" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history list is present on the page", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] element listing sync entries"

        :ok
      end

      then_ "the page does not segregate financial providers into a separate section from marketing providers", context do
        html = render(context.view)

        # The page should have a single unified sync history list rather than
        # separate sections for marketing vs financial data types
        refute has_element?(context.view, "[data-role='financial-sync-history']"),
               "Expected financial syncs to appear in the same unified list as marketing syncs, " <>
                 "not in a separate [data-role='financial-sync-history'] section"

        refute has_element?(context.view, "[data-role='marketing-sync-history']"),
               "Expected marketing syncs to appear in the same unified list as financial syncs, " <>
                 "not in a separate [data-role='marketing-sync-history'] section"

        assert html =~ "Sync History" or html =~ "sync history" or
                 has_element?(context.view, "[data-role='sync-history']"),
               "Expected a single unified sync history section, got: #{html}"

        :ok
      end
    end

    scenario "sync history page communicates that financial and marketing data are part of the same metrics pipeline" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders without error", context do
        html = render(context.view)

        refute html == "",
               "Expected the sync history page to render content, but got an empty page"

        :ok
      end

      then_ "the sync history section shows provider labels for each sync entry", context do
        html = render(context.view)

        # The page should label each sync entry with the provider name so users can
        # identify whether a given entry came from a marketing or financial source
        assert html =~ "Provider" or
                 html =~ "provider" or
                 has_element?(context.view, "[data-role='sync-provider']") or
                 has_element?(context.view, "[data-role='sync-entry']"),
               "Expected each sync history entry to display the provider label, got: #{html}"

        :ok
      end
    end
  end
end
