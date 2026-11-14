defmodule MetricFlowSpex.Story57.Criterion1037Spex do
  @moduledoc "A new channel backfills only its available daily history."
  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "A new channel backfills only what exists", criterion: 1037 do
    scenario "ninety available days appear on All Metrics and the sync succeeds" do
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

      given_ "the channel was created ninety days ago", context do
        created_on = Date.add(Date.utc_today(), -90)
        yesterday = Date.add(Date.utc_today(), -1)

        Application.put_env(:metric_flow, :req_http_options,
          plug: fn conn ->
            MetricFlowTest.YouTubeHistoryHttpFixture.respond(conn, created_on, yesterday)
          end
        )

        {:ok, Map.merge(context, %{created_on: created_on, yesterday: yesterday})}
      end

      when_ "the daily sync runs", context do
        {:ok, history, _html} = live(context.conn, ~p"/app/integrations/sync-history")
        history |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true, with_scheduled: true)
        {:ok, context}
      end

      then_ "All Metrics contains exactly the ninety available daily values", context do
        {:ok, dashboard, _html} = live(context.conn, ~p"/app/dashboard")

        dashboard
        |> element("[data-role='platform-filter'] button[phx-value-platform='youtube']")
        |> render_click()

        dashboard
        |> element("[data-role='date-range-filter'] button[phx-value-range='custom']")
        |> render_click()

        dashboard
        |> form("[data-role='custom-date-picker'] form", %{
          "start_date" => Date.to_iso8601(Date.add(Date.utc_today(), -548)),
          "end_date" => Date.to_iso8601(context.yesterday)
        })
        |> render_change()

        dashboard
        |> element("[data-role='granularity-toggle'] button[phx-value-granularity='day']")
        |> render_click()

        dashboard |> element("#deselect-all-metrics") |> render_click()
        dashboard |> element("#metric-toggle-views") |> render_click()
        assert has_element?(dashboard, "#metric-toggle-views[aria-pressed='true']")

        rows =
          dashboard
          |> render()
          |> LazyHTML.from_fragment()
          |> LazyHTML.query("[data-role='data-table'] tbody tr")
          |> Enum.map(fn row ->
            date = row |> LazyHTML.query("td:first-child") |> LazyHTML.text() |> String.trim()

            value =
              row
              |> LazyHTML.query("td:nth-child(2)")
              |> LazyHTML.text()
              |> String.trim()
              |> String.replace(",", "")
              |> Float.parse()

            {date, value}
          end)

        expected =
          Date.range(context.created_on, context.yesterday)
          |> Enum.map(fn day ->
            {Date.to_iso8601(day), {(Date.diff(day, context.created_on) + 1) * 1.0, ""}}
          end)

        assert Enum.sort(rows) == Enum.sort(expected)
        {:ok, context}
      end

      then_ "Sync History records a successful YouTube sync", context do
        {:ok, history, _html} = live(context.conn, ~p"/app/integrations/sync-history")

        assert has_element?(
                 history,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "YouTube"
               )

        {:ok, context}
      end
    end
  end
end
