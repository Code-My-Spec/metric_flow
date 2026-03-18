defmodule MetricFlowSpex.IntegrationIsSavedOnlyAfterSuccessfulOAuthCompletionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Integration is saved only after successful OAuth completion" do
    scenario "integrations page shows no platforms connected before OAuth completion" do
      given_ :user_logged_in_as_owner

      given_ "the user views the integrations page before completing any OAuth flow", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no integrations are shown as active or connected", context do
        html = render(context.view)
        refute html =~ "Active"
        refute html =~ "Connected"
        :ok
      end
    end

    scenario "integration connect page shows pending state before OAuth" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the connect page for Google", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the provider is not shown as saved or active yet", context do
        html = render(context.view)
        refute html =~ "Integration saved"
        refute html =~ "Integration active"
        :ok
      end

      then_ "the user sees a button or link to begin the OAuth process", context do
        assert has_element?(context.view, "[data-role='oauth-connect-button']") or
                 has_element?(context.view, "a[href*='oauth']") or
                 render(context.view) =~ "Connect" or
                 render(context.view) =~ "Authorize"
        :ok
      end
    end

    scenario "OAuth callback page shows success confirmation after completing OAuth" do
      given_ :owner_with_google_ads_integration

      given_ "the user navigates to the Google detail page after OAuth", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page acknowledges the OAuth flow has completed", context do
        html = render(context.view)
        assert html =~ "connected" or html =~ "Connected" or html =~ "success" or
                 html =~ "saved" or html =~ "authorized" or html =~ "Authorized"

        :ok
      end
    end
  end
end
