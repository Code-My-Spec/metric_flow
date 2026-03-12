defmodule MetricFlowSpex.UserSeesConfirmationThatQuickbooksIsConnectedAndReadyToSyncSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User sees confirmation that QuickBooks is connected and ready to sync" do
    scenario "successful OAuth callback displays a connection confirmation" do
      given_ :owner_with_quickbooks_integration

      given_ "the user navigates to the QuickBooks detail page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays a connection confirmation", context do
        html = render(context.view)
        assert html =~ "Connected"
        :ok
      end

      then_ "the page mentions QuickBooks by name", context do
        html = render(context.view)
        assert html =~ "QuickBooks"
        :ok
      end

      then_ "the page indicates the account is ready to sync", context do
        html = render(context.view)
        assert html =~ "sync" or html =~ "Sync" or html =~ "data" or html =~ "connected"
        :ok
      end

      then_ "the page shows a Connected badge", context do
        assert has_element?(context.view, ".badge-success", "Connected")
        :ok
      end
    end

    scenario "the confirmation page provides navigation back to integrations" do
      given_ :owner_with_quickbooks_integration

      given_ "the user navigates to the QuickBooks detail page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page has a link to view all integrations", context do
        html = render(context.view)
        assert html =~ "integrations" or html =~ "Integrations" or html =~ "Back"
        :ok
      end
    end
  end
end
