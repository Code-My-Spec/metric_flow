defmodule MetricFlowSpex.FailedOauthAttemptsShowClearErrorMessagesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Failed OAuth attempts show clear error messages" do
    scenario "access denied error shows a clear denial message" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback returns with an access_denied error", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/quickbooks?error=access_denied"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays a connection failed heading", context do
        html = render(context.view)
        assert html =~ "Connection Failed"
        :ok
      end

      then_ "the page shows that access was denied", context do
        html = render(context.view)
        assert html =~ "denied"
        :ok
      end

      then_ "the page provides a try again link", context do
        html = render(context.view)
        assert html =~ "Try again"
        :ok
      end
    end

    scenario "generic OAuth error shows the error details" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback returns with a server error", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/quickbooks?error=server_error&error_description=Something+went+wrong"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays the error information", context do
        html = render(context.view)
        assert html =~ "server_error" or html =~ "Something went wrong"
        :ok
      end

      then_ "the page shows the integration is not active", context do
        html = render(context.view)
        assert html =~ "not active" or html =~ "Failed"
        :ok
      end
    end

    scenario "missing authorization code shows a clear error" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback is invoked without any parameters", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/oauth/callback/quickbooks")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a no authorization code error", context do
        html = render(context.view)
        assert html =~ "No authorization code" or html =~ "Failed"
        :ok
      end
    end

    scenario "the error page provides navigation back to integrations" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback returns with an error", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/quickbooks?error=access_denied"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page has a link back to integrations", context do
        html = render(context.view)
        assert html =~ "Back to integrations"
        :ok
      end
    end
  end
end
