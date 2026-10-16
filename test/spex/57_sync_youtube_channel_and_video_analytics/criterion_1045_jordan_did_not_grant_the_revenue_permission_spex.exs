defmodule MetricFlowSpex.Story57.Criterion1045Spex do
  @moduledoc "Missing revenue consent leaves channel analytics available."
  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Jordan did not grant the revenue permission", criterion: 1045 do
    scenario "analytics sync succeeds while revenue is skipped with an explanation" do
      given_(:user_logged_in_as_owner)

      given_ "Jordan connects a channel without granting revenue access", context do
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
          youtube: MetricFlowTest.YouTubeNoRevenueOAuthProvider
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

      given_ "Google returns yesterday's channel audience and engagement metrics", context do
        day = Date.add(Date.utc_today(), -1)
        metrics = MetricFlowTest.YouTubeAnalyticsHttpFixture.channel_metrics()

        Application.put_env(:metric_flow, :req_http_options,
          plug: fn conn ->
            conn = Plug.Conn.fetch_query_params(conn)
            requested = String.split(conn.query_params["metrics"] || "", ",")

            if Enum.any?(requested, &(&1 in ["estimatedRevenue", "adImpressions", "cpm"])) do
              conn
              |> Plug.Conn.put_resp_content_type("application/json")
              |> Plug.Conn.send_resp(
                403,
                Jason.encode!(%{
                  "error" => %{"code" => 403, "message" => "Revenue permission was not granted"}
                })
              )
            else
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

      then_ "All Metrics shows each synced channel metric for yesterday", context do
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

        expected = [
          {"views", 1200},
          {"estimatedminuteswatched", 3000},
          {"subscribersgained", 15},
          {"subscriberslost", 2},
          {"likes", 40},
          {"dislikes", 3},
          {"comments", 12},
          {"shares", 8},
          {"averageviewduration", 150},
          {"averageviewpercentage", 50},
          {"videosaddedtoplaylists", 9},
          {"videosremovedfromplaylists", 1}
        ]

        for {metric, value} <- expected do
          dashboard |> element("#deselect-all-metrics") |> render_click()
          dashboard |> element("#metric-toggle-#{metric}") |> render_click()
          assert has_element?(dashboard, "#metric-toggle-#{metric}[aria-pressed='true']")
          assert has_element?(dashboard, "[data-role='data-table'] th", metric)

          cells =
            dashboard
            |> render()
            |> LazyHTML.from_fragment()
            |> LazyHTML.query("[data-role='data-table'] tbody tr td:nth-child(2)")
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

      then_ "no revenue metrics are available and Sync History explains the missing permission",
            context do
        {:ok, dashboard, _html} = live(context.conn, ~p"/app/dashboard")

        dashboard
        |> element("[data-role='platform-filter'] button[phx-value-platform='youtube']")
        |> render_click()

        assert has_element?(dashboard, "#metric-toggle-views")

        for metric <- ["estimatedrevenue", "adimpressions", "cpm"] do
          refute has_element?(dashboard, "#metric-toggle-#{metric}")
        end

        {:ok, history, _html} = live(context.conn, ~p"/app/integrations/sync-history")
        entry = "[data-role='sync-history-entry']"
        assert has_element?(history, entry <> " [data-role='sync-provider']", "YouTube")
        assert has_element?(history, entry, ~r/revenue.*skipped/i)
        assert has_element?(history, entry, ~r/permission.*not granted/i)
        {:ok, context}
      end
    end
  end
end
