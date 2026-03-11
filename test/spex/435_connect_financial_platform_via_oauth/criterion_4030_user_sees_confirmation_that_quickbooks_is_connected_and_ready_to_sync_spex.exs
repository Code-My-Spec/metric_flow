defmodule MetricFlowSpex.UserSeesConfirmationThatQuickbooksIsConnectedAndReadyToSyncSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User sees confirmation that QuickBooks is connected and ready to sync" do
    scenario "successful OAuth callback displays a connection confirmation" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback completes successfully", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/oauth/callback/quickbooks?code=valid_code")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays an integration active confirmation", context do
        html = render(context.view)
        assert html =~ "Integration Active"
        :ok
      end

      then_ "the page mentions QuickBooks by name", context do
        html = render(context.view)
        assert html =~ "QuickBooks"
        :ok
      end

      then_ "the page indicates the account is ready to sync", context do
        html = render(context.view)
        assert html =~ "ready to sync" or html =~ "connected and ready"
        :ok
      end

      then_ "the page shows an Active badge", context do
        assert has_element?(context.view, ".badge-success", "Active")
        :ok
      end
    end

    scenario "the confirmation page provides navigation back to integrations" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback completes successfully", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/oauth/callback/quickbooks?code=valid_code")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page has a link to view all integrations", context do
        html = render(context.view)
        assert html =~ "View Integrations"
        :ok
      end

      then_ "the page has a link to connect another platform", context do
        html = render(context.view)
        assert html =~ "Connect another platform"
        :ok
      end
    end
  end
end
