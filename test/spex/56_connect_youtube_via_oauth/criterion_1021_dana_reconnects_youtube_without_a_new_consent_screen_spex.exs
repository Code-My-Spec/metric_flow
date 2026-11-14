defmodule MetricFlowSpex.Story56.Criterion1021Spex do
  @moduledoc """
  Story 56, criterion 1021: reconnecting with existing YouTube permissions
  opens channel selection without another Google consent request.
  The existing connection is established through OAuth and the selection UI.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana reconnects YouTube without a new consent screen", criterion: 1021 do
    scenario "an authorized connection goes directly to channel selection" do
      given_(:user_logged_in_as_owner)

      given_ "Google supplies valid YouTube permissions and Dana's channels", context do
        originals =
          for key <- [:oauth_providers, :req_http_options],
              do: {key, Application.fetch_env(:metric_flow, key)}

        on_exit(fn ->
          for {key, value} <- originals do
            case value do
              {:ok, original} -> Application.put_env(:metric_flow, key, original)
              :error -> Application.delete_env(:metric_flow, key)
            end
          end
        end)

        Application.put_env(:metric_flow, :oauth_providers, %{
          youtube: MetricFlowTest.YouTubeOAuthProvider
        })

        Application.put_env(:metric_flow, :req_http_options,
          plug: &MetricFlowTest.YouTubeOAuthProvider.respond/1
        )

        {:ok, context}
      end

      given_ "Dana has connected YouTube and selected her personal channel", context do
        request = get(context.owner_conn, ~p"/app/integrations/oauth/youtube")

        params =
          request |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        callback =
          request
          |> recycle()
          |> get(~p"/app/integrations/oauth/callback/youtube", %{
            "code" => "synthetic-youtube-code",
            "state" => Map.fetch!(params, "state")
          })

        conn = recycle(callback)
        {:ok, selection, _html} = live(conn, redirected_to(callback))

        selection
        |> form("[data-role='account-selection']", %{"channel_ids" => ["UC_dana_personal"]})
        |> render_submit()

        {:ok, integrations, _html} = live(conn, ~p"/app/integrations")
        {:ok, platforms, _html} = live(conn, ~p"/app/integrations/connect")

        {:ok, Map.merge(context, %{conn: conn, integrations: integrations, platforms: platforms})}
      end

      when_ "Dana reconnects YouTube", context do
        result =
          context.platforms
          |> element("[data-platform='youtube'] [data-role='connect-button']", "Reconnect")
          |> render_click()

        {:ok, Map.put(context, :reconnect_result, result)}
      end

      then_ "she goes straight to channel selection without Google consent", context do
        assert has_element?(
                 context.integrations,
                 "[data-role='integration-card'][data-platform='youtube'][data-status='connected']"
               )

        assert {:error, {:live_redirect, %{to: path}}} = context.reconnect_result
        assert path == ~p"/app/integrations/connect/youtube/accounts"

        {:ok, selection, _html} = follow_redirect(context.reconnect_result, context.conn, path)
        assert has_element?(selection, "[data-role='account-selection']")
        assert has_element?(selection, "[data-role='account-option']", "Dana Personal")
        assert has_element?(selection, "[data-role='account-option']", "Dana Brand")
        refute has_element?(selection, "[data-role='oauth-connect-button']")
        {:ok, context}
      end
    end
  end
end
