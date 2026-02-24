defmodule MetricFlowSpex.AfterSuccessfulAuthenticationUserIsRedirectedBackToPlatformSelectionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "After successful authentication, user is redirected back to platform selection" do
    scenario "after OAuth callback with a success code, the user lands on the platform selection page" do
      given_ :user_logged_in_as_owner

      given_ "the user visits the OAuth callback URL with a success authorization code", context do
        conn = get(context.owner_conn, "/integrations/callback/google_ads", %{
          "code" => "mock_auth_code_123",
          "state" => "some_state_token"
        })
        {:ok, Map.put(context, :callback_conn, conn)}
      end

      then_ "the user is redirected to the integrations connect page", context do
        assert redirected_to(context.callback_conn) == "/integrations/connect" or
                 redirected_to(context.callback_conn) =~ "/integrations"
        :ok
      end
    end

    scenario "after OAuth callback with a success code for Facebook Ads, user lands on the platform selection page" do
      given_ :user_logged_in_as_owner

      given_ "the user visits the Facebook Ads OAuth callback URL with a success authorization code", context do
        conn = get(context.owner_conn, "/integrations/callback/facebook_ads", %{
          "code" => "mock_auth_code_456",
          "state" => "some_state_token"
        })
        {:ok, Map.put(context, :callback_conn, conn)}
      end

      then_ "the user is redirected back to the integrations page after Facebook Ads OAuth completes", context do
        assert redirected_to(context.callback_conn) == "/integrations/connect" or
                 redirected_to(context.callback_conn) =~ "/integrations"
        :ok
      end
    end

    scenario "the integrations connect page shows a success indicator after successful OAuth callback" do
      given_ :user_logged_in_as_owner

      given_ "the user visits the OAuth callback URL and is redirected back to the connect page", context do
        callback_conn = get(context.owner_conn, "/integrations/callback/google_ads", %{
          "code" => "mock_auth_code_789",
          "state" => "some_state_token"
        })

        redirect_path = redirected_to(callback_conn)
        follow_conn = recycle(callback_conn)
        {:ok, view, _html} = live(follow_conn, redirect_path)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees confirmation that the platform has been connected", context do
        html = render(context.view)
        assert html =~ "connected" or html =~ "Connected" or html =~ "success" or html =~ "Success"
        :ok
      end
    end

    scenario "the integrations connect page shows the platform as connected after successful OAuth" do
      given_ :user_logged_in_as_owner

      given_ "the user visits the integrations connect page after a successful Google Ads OAuth callback", context do
        callback_conn = get(context.owner_conn, "/integrations/callback/google_ads", %{
          "code" => "mock_auth_code_success",
          "state" => "some_state_token"
        })

        redirect_path = redirected_to(callback_conn)
        follow_conn = recycle(callback_conn)
        {:ok, view, _html} = live(follow_conn, redirect_path)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Google Ads platform shows as connected or in an account selection state", context do
        html = render(context.view)
        assert html =~ "Google Ads"
        assert html =~ "connected" or html =~ "Connected" or html =~ "select" or html =~ "Select"
        :ok
      end
    end
  end
end
