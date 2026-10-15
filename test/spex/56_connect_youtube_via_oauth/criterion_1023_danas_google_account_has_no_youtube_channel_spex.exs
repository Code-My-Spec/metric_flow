defmodule MetricFlowSpex.Story56.Criterion1023Spex do
  @moduledoc """
  Story 56, criterion 1023: an account without YouTube channels gets a clear
  explanation and no saved YouTube integration. Observes only web surfaces.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana's Google account has no YouTube channel", criterion: 1023 do
    scenario "an empty channel response leaves YouTube unconnected" do
      given_(:user_logged_in_as_owner)

      given_ "Dana signs in with a Google account that has no channels", context do
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
          plug: fn
            %Plug.Conn{method: "GET", request_path: "/youtube/v3/channels"} = conn ->
              conn
              |> Plug.Conn.put_resp_content_type("application/json")
              |> Plug.Conn.send_resp(
                200,
                Jason.encode!(%{
                  "kind" => "youtube#channelListResponse",
                  "pageInfo" => %{"totalResults" => 0, "resultsPerPage" => 0},
                  "items" => []
                })
              )

            conn ->
              MetricFlowTest.YouTubeOAuthProvider.respond(conn)
          end
        )

        request = get(context.owner_conn, ~p"/app/integrations/oauth/youtube")

        params =
          request |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        {:ok,
         Map.merge(context, %{
           oauth_conn: recycle(request),
           oauth_state: Map.fetch!(params, "state")
         })}
      end

      when_ "Dana finishes signing in to YouTube", context do
        callback =
          get(context.oauth_conn, ~p"/app/integrations/oauth/callback/youtube", %{
            "code" => "synthetic-youtube-code",
            "state" => context.oauth_state
          })

        {:ok, Map.put(context, :callback, callback)}
      end

      then_ "she is told no YouTube channel was found for that account", context do
        {:ok, view, _html} = live(recycle(context.callback), redirected_to(context.callback))
        assert has_element?(view, "[role='alert']", ~r/no YouTube channels?.*found/i)
        {:ok, context}
      end

      then_ "no YouTube integration is saved", context do
        conn = recycle(context.callback)
        {:ok, integrations, _html} = live(conn, ~p"/app/integrations")
        assert has_element?(integrations, "[data-role='integrations-index']")

        refute has_element?(
                 integrations,
                 "[data-role='integration-card'][data-platform='youtube']"
               )

        {:ok, platforms, _html} = live(conn, ~p"/app/integrations/connect")

        assert has_element?(
                 platforms,
                 "[data-platform='youtube'] [data-role='connect-button']",
                 "Connect"
               )

        refute has_element?(
                 platforms,
                 "[data-platform='youtube'] [data-role='connect-button']",
                 "Reconnect"
               )

        {:ok, context}
      end
    end
  end
end
