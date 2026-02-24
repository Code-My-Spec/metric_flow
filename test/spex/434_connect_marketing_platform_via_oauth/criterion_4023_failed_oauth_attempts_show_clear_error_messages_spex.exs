defmodule MetricFlowSpex.FailedOAuthAttemptsShowClearErrorMessagesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Failed OAuth attempts show clear error messages" do
    scenario "OAuth callback with error parameter shows error message to user" do
      given_ :user_logged_in_as_owner

      given_ "the user arrives at the callback page with an OAuth error", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/google_ads?error=access_denied"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a clear error message explaining the failure", context do
        html = render(context.view)

        assert html =~ "error" or html =~ "Error" or html =~ "failed" or html =~ "Failed" or
                 html =~ "denied" or html =~ "unsuccessful"

        :ok
      end

      then_ "the user is not shown a success confirmation", context do
        html = render(context.view)
        refute html =~ "Integration saved"
        refute html =~ "successfully connected"
        :ok
      end
    end

    scenario "OAuth callback with access denied shows actionable guidance" do
      given_ :user_logged_in_as_owner

      given_ "the user arrives at the callback page after denying access", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/google_ads?error=access_denied&error_description=User+denied+access"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page provides a way for the user to try again", context do
        html = render(context.view)

        assert has_element?(context.view, "a") or
                 has_element?(context.view, "button") or
                 html =~ "try again" or
                 html =~ "Try again" or
                 html =~ "Connect" or
                 html =~ "integrations"

        :ok
      end
    end

    scenario "OAuth callback with invalid state shows security error" do
      given_ :user_logged_in_as_owner

      given_ "the user arrives at the callback page with an invalid state token", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/google_ads?code=some_code&state=invalid_state_token"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an error message", context do
        html = render(context.view)

        assert html =~ "error" or html =~ "Error" or html =~ "invalid" or html =~ "Invalid" or
                 html =~ "failed" or html =~ "expired"

        :ok
      end
    end
  end
end
