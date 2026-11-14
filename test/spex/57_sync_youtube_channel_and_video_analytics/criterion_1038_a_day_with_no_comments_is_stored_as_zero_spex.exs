defmodule MetricFlowSpex.Story57.Criterion1038Spex do
  @moduledoc "Verifies a missing comments value through the All Metrics dashboard."
  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "A day with no comments is stored as zero", criterion: 1038 do
    scenario "yesterday's missing comments value appears as zero" do
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

      given_ "Google returns no comments value for yesterday", context do
        day = Date.add(Date.utc_today(), -1)
        metrics = MetricFlowTest.YouTubeAnalyticsHttpFixture.channel_metrics(%{"comments" => nil})

        Application.put_env(:metric_flow, :req_http_options,
          plug: fn conn ->
            MetricFlowTest.YouTubeAnalyticsHttpFixture.respond(conn, day, metrics)
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

      then_ "All Metrics shows zero comments for yesterday", context do
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

        dashboard |> element("#deselect-all-metrics") |> render_click()
        dashboard |> element("#metric-toggle-comments") |> render_click()

        assert has_element?(dashboard, "#metric-toggle-comments[aria-pressed='true']")
        assert has_element?(dashboard, "[data-role='data-table'] th", "comments")
        assert has_element?(dashboard, "[data-role='data-table'] tbody tr")

        assert has_element?(
                 dashboard,
                 "[data-role='data-table'] tbody tr td:nth-child(2)",
                 ~r/^0(?:[.,]0+)?$/
               )

        {:ok, context}
      end
    end
  end
end
