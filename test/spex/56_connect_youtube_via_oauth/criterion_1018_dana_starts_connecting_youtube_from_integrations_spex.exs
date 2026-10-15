defmodule MetricFlowSpex.Story56.Criterion1018Spex do
  @moduledoc """
  Story 56: Connect YouTube via OAuth.
  Criterion 1018: Dana starts connecting YouTube from Integrations.

  Drives registration, login, platform selection, and the real OAuth request
  controller. Google's sign-in is observed through its authorization redirect;
  no Google credentials or external browser session are required.
  """

  use MetricFlowSpex.Case

  spex "Dana starts connecting YouTube from Integrations", criterion: 1018 do
    scenario "a client chooses YouTube and reaches Google sign-in" do
      given_ "Dana is signed in to her client account", context do
        email = "dana-youtube-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"
        {:ok, registration, _html} = live(context.conn, ~p"/users/register")

        registration
        |> form("#registration_form",
          user: %{
            email: email,
            password: password,
            account_name: "Dana's business",
            account_type: "client"
          }
        )
        |> render_submit()

        login_conn = build_conn()
        {:ok, login, _html} = live(login_conn, ~p"/users/log-in")

        conn =
          login
          |> form("#login_form_password", user: %{email: email, password: password})
          |> submit_form(login_conn)
          |> recycle()

        {:ok, Map.put(context, :conn, conn)}
      end

      given_ "Dana opens platform selection from the integrations page", context do
        {:ok, integrations, _html} = live(context.conn, ~p"/app/integrations")

        {:ok, selection, _html} =
          integrations
          |> element("a[href='/app/integrations/connect']", "Connect a Platform")
          |> render_click()
          |> follow_redirect(context.conn, ~p"/app/integrations/connect")

        {:ok, Map.put(context, :selection, selection)}
      end

      when_ "Dana chooses to connect YouTube", context do
        context.selection
        |> element("[data-platform='youtube'] [data-role='connect-button']")
        |> render_click()

        {:ok, context}
      end

      then_ "Google sign-in opens for YouTube", context do
        {oauth_path, _flash} = assert_redirect(context.selection)
        assert oauth_path == ~p"/app/integrations/oauth/youtube"

        response = get(context.conn, oauth_path)
        authorization_uri = response |> redirected_to() |> URI.parse()
        assert authorization_uri.scheme == "https"
        assert authorization_uri.host == "accounts.google.com"

        params = URI.decode_query(authorization_uri.query || "")
        assert params["response_type"] == "code"
        assert is_binary(params["state"]) and params["state"] != ""

        assert "https://www.googleapis.com/auth/youtube.readonly" in String.split(
                 params["scope"] || ""
               )

        {:ok, context}
      end
    end
  end
end
