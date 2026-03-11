defmodule MetricFlowSpex.IntegrationIsSavedOnlyAfterSuccessfulOauthCompletionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Integration is saved only after successful OAuth completion" do
    scenario "before OAuth completion the integrations list does not show QuickBooks as connected" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no QuickBooks integration is listed as connected", context do
        html = render(context.view)
        refute html =~ "QuickBooks" and html =~ "Connected"
        :ok
      end
    end

    scenario "a failed OAuth callback does not create an integration" do
      given_ :user_logged_in_as_owner

      given_ "the OAuth callback returns with an error", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/quickbooks?error=access_denied"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the callback page shows an error status", context do
        html = render(context.view)
        assert html =~ "denied" or html =~ "Failed" or html =~ "error"
        :ok
      end

      when_ "the user navigates to the integrations list", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :list_view, view)}
      end

      then_ "QuickBooks is not shown as a connected integration", context do
        html = render(context.list_view)
        refute html =~ "QuickBooks" and html =~ "Connected"
        :ok
      end
    end

    scenario "a successful OAuth callback creates the integration" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback returns with a valid authorization code", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/oauth/callback/quickbooks?code=valid_code")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the callback page shows the integration is active", context do
        html = render(context.view)
        assert html =~ "Active" or html =~ "connected" or html =~ "Integration Active"
        :ok
      end
    end
  end
end
