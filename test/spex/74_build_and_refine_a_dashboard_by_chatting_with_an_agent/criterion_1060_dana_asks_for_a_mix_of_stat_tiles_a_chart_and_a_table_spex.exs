defmodule MetricFlowSpex.Story74.Criterion1060Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1060 — Dana asks for a mix of a stat tile, a chart and a
  table, in one request, and the dashboard shows all three with real
  data.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana asks for a mix of stat tiles, a chart and a table", criterion: 1060 do
    scenario "a single request produces a stat, a chart and a table together" do
      given_(:user_logged_in_as_owner)

      given_ "Dana has synced metrics", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "impressions",
          value: 100.0,
          recorded_at: DateTime.add(DateTime.utc_now(), -5, :day)
        })

        {:ok, context}
      end

      given_ "Dana opens a new dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she asks for a headline stat, a spend-over-time line chart and a table of campaigns",
            context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.ClaudeCodeStub.sequence(
            MetricFlowTest.ClaudeCodeStub.completed_tool_call(
              "set_dashboard_spec",
              %{
                "a2ui_json" =>
                  Jason.encode!(%{
                    "components" => [
                      %{
                        "id" => "widget-0",
                        "type" => "stat",
                        "title" => "Total Impressions",
                        "query" => %{"metric" => "impressions"}
                      },
                      %{
                        "id" => "widget-1",
                        "type" => "chart",
                        "chartType" => "line",
                        "title" => "Spend Over Time",
                        "query" => %{"metric" => "impressions"}
                      },
                      %{
                        "id" => "widget-2",
                        "type" => "table",
                        "title" => "Campaigns",
                        "query" => %{"metric" => "impressions"}
                      }
                    ]
                  })
              },
              completion_text: "Here's a stat, a chart and a table of your campaigns."
            )
          )
        )

        render_submit(context.view, "send_dashboard_chat", %{
          "message" =>
            "Show me a headline stat, a spend-over-time line chart and a table of campaigns"
        })

        await_dashboard_chat_completion(context.view)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "the dashboard shows a stat tile, a line chart and a table in a layout", context do
        assert has_element?(context.view, "[data-role='stat-tile-value']")
        assert has_element?(context.view, "[data-role='echarts-chart']")
        assert has_element?(context.view, "table")
        {:ok, context}
      end

      then_ "all of them show her real data", context do
        html = render(context.view)
        refute html =~ "No data for this period"
        {:ok, context}
      end
    end
  end
end
