defmodule MetricFlowSpex.Story57.Criterion1041Spex do
  @moduledoc """
  Story 57: exhausted YouTube quota is retried and reported in Sync History.
  Establishes the integration through OAuth and channel selection. Only
  external Google responses are simulated; no sync records are seeded.
  """
  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "YouTube's daily request limit is reached", criterion: 1041, fail_on_error_logs: false do
    scenario "quota exhaustion is retried before a persisted failure is shown" do
      given_(:user_logged_in_as_owner)

      given_ "Dana has connected a YouTube channel", context do
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

        {:ok, Map.put(context, :conn, conn)}
      end

      given_ "Google rejects data requests because the daily quota is exhausted", context do
        requests = start_supervised!({Agent, fn -> %{} end})

        Application.put_env(:metric_flow, :req_http_options,
          plug: fn conn ->
            key = {conn.method, conn.host, conn.request_path, conn.query_string}
            Agent.update(requests, &Map.update(&1, key, 1, fn count -> count + 1 end))

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(
              403,
              Jason.encode!(%{
                "error" => %{
                  "code" => 403,
                  "message" => "Daily YouTube request quota exceeded",
                  "errors" => [
                    %{
                      "domain" => "youtube.quota",
                      "reason" => "quotaExceeded",
                      "message" => "Daily YouTube request quota exceeded"
                    }
                  ]
                }
              })
            )
          end
        )

        {:ok, Map.put(context, :requests, requests)}
      end

      when_ "the daily sync runs and scheduled retries are processed", context do
        {:ok, history, _html} = live(context.conn, ~p"/app/integrations/sync-history")
        history |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true, with_scheduled: true)
        {:ok, context}
      end

      then_ "at least one rejected request has been retried", context do
        counts = Agent.get(context.requests, &Map.values/1)

        assert Enum.any?(counts, &(&1 > 1)),
               "Expected a repeated request to Google after quota exhaustion"

        {:ok, context}
      end

      then_ "Sync History retains the failed YouTube sync and its quota cause", context do
        {:ok, history, _html} = live(context.conn, ~p"/app/integrations/sync-history")
        failed = "[data-role='sync-history-entry'][data-status='failed']"
        assert has_element?(history, failed <> " [data-role='sync-provider']", "YouTube")

        assert has_element?(
                 history,
                 failed <> " [data-role='sync-error']",
                 ~r/(daily.*(limit|quota)|quota.*exceeded)/i
               )

        {:ok, context}
      end
    end
  end
end
