defmodule MetricFlowSpex.Story57.Criterion1030Spex do
  @moduledoc "Both selected channels contribute distinct daily values to All Metrics."
  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana's two channels sync overnight", criterion: 1030 do
    scenario "yesterday's dashboard totals include both selected channels" do
      given_(:user_logged_in_as_owner)

      given_ "Dana connects YouTube and selects both channels", context do
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
        |> form("[data-role='account-selection']", %{
          "channel_ids" => ["UC_dana_personal", "UC_dana_brand"]
        })
        |> render_submit()

        {:ok, Map.put(context, :conn, conn)}
      end

      given_ "Google returns distinct daily data for each channel", context do
        day = Date.add(Date.utc_today(), -1)
        metrics = MetricFlowTest.YouTubeAnalyticsHttpFixture.channel_metrics()

        Application.put_env(:metric_flow, :req_http_options,
          plug: fn conn ->
            conn = Plug.Conn.fetch_query_params(conn)

            case conn.request_path do
              "/youtube/v3/channels" ->
                ids =
                  String.split(conn.query_params["id"] || "UC_dana_personal,UC_dana_brand", ",")

                items =
                  for id <- ids do
                    %{
                      "id" => id,
                      "snippet" => %{"title" => id, "publishedAt" => "2020-01-01T00:00:00Z"},
                      "contentDetails" => %{"relatedPlaylists" => %{"uploads" => "uploads-#{id}"}},
                      "statistics" => %{
                        "subscriberCount" => "100",
                        "viewCount" => "9000",
                        "videoCount" => "0"
                      }
                    }
                  end

                conn
                |> Plug.Conn.put_resp_content_type("application/json")
                |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => items}))

              "/v2/reports" ->
                values =
                  case conn.query_params["ids"] do
                    "channel==UC_dana_personal" ->
                      metrics

                    "channel==UC_dana_brand" ->
                      Map.merge(metrics, %{
                        "views" => 700,
                        "estimatedMinutesWatched" => 1100,
                        "comments" => 7
                      })

                    other ->
                      raise "Expected a selected channel identity, got #{inspect(other)}"
                  end

                MetricFlowTest.YouTubeAnalyticsHttpFixture.respond(conn, day, values)

              _ ->
                MetricFlowTest.YouTubeAnalyticsHttpFixture.respond(conn, day, metrics)
            end
          end
        )

        {:ok, Map.put(context, :day, day)}
      end

      when_ "the daily sync runs", context do
        {:ok, history, _html} = live(context.conn, ~p"/app/integrations/sync-history")
        history |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true, with_scheduled: true)
        {:ok, context}
      end

      then_ "All Metrics includes yesterday's values from both channels", context do
        {:ok, dashboard, _html} = live(context.conn, ~p"/app/dashboard")

        dashboard
        |> element("[data-role='platform-filter'] button[phx-value-platform='youtube']")
        |> render_click()

        dashboard
        |> element("[data-role='date-range-filter'] button[phx-value-range='custom']")
        |> render_click()

        dashboard
        |> form("[data-role='custom-date-picker'] form", %{
          "start_date" => Date.to_iso8601(context.day),
          "end_date" => Date.to_iso8601(context.day)
        })
        |> render_change()

        expected = [{"views", 1900}, {"estimatedminuteswatched", 4100}, {"comments", 19}]

        for {metric, value} <- expected do
          dashboard |> element("#deselect-all-metrics") |> render_click()
          dashboard |> element("#metric-toggle-#{metric}") |> render_click()
          assert has_element?(dashboard, "#metric-toggle-#{metric}[aria-pressed='true']")
          assert has_element?(dashboard, "[data-role='data-table'] th", metric)

          cells =
            dashboard
            |> render()
            |> LazyHTML.from_fragment()
            |> LazyHTML.filter("[data-role='data-table'] tbody tr td:nth-child(2)")
            |> Enum.map(fn cell ->
              cell
              |> LazyHTML.text()
              |> String.trim()
              |> String.replace(",", "")
              |> Float.parse()
            end)

          assert [{actual, ""}] = cells
          assert actual == value, "Expected #{metric} to equal #{value}, got #{actual}"
        end

        {:ok, context}
      end
    end
  end
end
