defmodule MetricFlowSpex.Story56.Criterion1020Spex do
  @moduledoc """
  Story 56, criterion 1020: Analytics consent does not authorize YouTube.
  Establishes Analytics through the real OAuth request and callback, with
  synthetic external HTTP responses granting Analytics-only permissions.
  Restores the production provider mapping before initiating YouTube.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana's Google Analytics connection does not count as YouTube consent", criterion: 1020 do
    scenario "an Analytics-connected client must authorize YouTube permissions" do
      given_(:user_logged_in_as_owner)

      given_ "Dana connects Google Analytics without any YouTube permissions", context do
        original = Application.fetch_env(:metric_flow, :oauth_providers)

        restore = fn ->
          case original do
            {:ok, providers} -> Application.put_env(:metric_flow, :oauth_providers, providers)
            :error -> Application.delete_env(:metric_flow, :oauth_providers)
          end
        end

        on_exit(restore)

        Application.put_env(:metric_flow, :oauth_providers, %{
          google_analytics: MetricFlowTest.AnalyticsOnlyOAuthProvider
        })

        conn =
          try do
            request = get(context.owner_conn, ~p"/app/integrations/oauth/google_analytics")

            params =
              request
              |> redirected_to()
              |> URI.parse()
              |> Map.fetch!(:query)
              |> URI.decode_query()

            request
            |> recycle()
            |> get(~p"/app/integrations/oauth/callback/google_analytics", %{
              "code" => "synthetic-analytics-code",
              "state" => Map.fetch!(params, "state")
            })
            |> recycle()
          after
            restore.()
          end

        {:ok, integrations, _html} = live(conn, ~p"/app/integrations")
        {:ok, selection, _html} = live(conn, ~p"/app/integrations/connect")
        {:ok, Map.merge(context, %{conn: conn, integrations: integrations, selection: selection})}
      end

      when_ "Dana connects YouTube", context do
        context.selection
        |> element("[data-platform='youtube'] [data-role='connect-button']")
        |> render_click()

        {:ok, context}
      end

      then_ "her Analytics connection remains and Google requests separate YouTube consent",
            context do
        assert has_element?(
                 context.integrations,
                 "[data-role='integration-card'][data-platform='google_analytics'][data-status='connected']"
               )

        refute has_element?(
                 context.integrations,
                 "[data-role='integration-card'][data-platform='youtube'][data-status='connected']"
               )

        path = assert_redirect(context.selection)
        assert path == ~p"/app/integrations/oauth/youtube"
        response = get(context.conn, path)
        uri = response |> redirected_to() |> URI.parse()
        assert uri.scheme == "https"
        assert uri.host == "accounts.google.com"

        params = URI.decode_query(uri.query || "")
        scopes = String.split(params["scope"] || "")
        assert "https://www.googleapis.com/auth/youtube.readonly" in scopes
        assert "https://www.googleapis.com/auth/yt-analytics.readonly" in scopes
        assert "consent" in String.split(params["prompt"] || "")
        {:ok, context}
      end
    end
  end
end
