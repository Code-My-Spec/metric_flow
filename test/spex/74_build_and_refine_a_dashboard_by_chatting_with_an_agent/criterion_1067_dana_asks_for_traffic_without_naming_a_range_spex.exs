defmodule MetricFlowSpex.Story74.Criterion1067Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1067 — Dana asks for traffic without naming a range: the
  chart defaults to the last 30 days ending yesterday, excluding
  today's incomplete data.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana asks for traffic without naming a range", criterion: 1067 do
    scenario "the default range ends yesterday and excludes today" do
      given_(:user_logged_in_as_owner)

      given_ "today is mid-month and Dana has synced metrics", context do
        now = DateTime.utc_now()

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "impressions",
          value: 7.0,
          recorded_at: now
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "impressions",
          value: 100.0,
          recorded_at: DateTime.add(now, -1, :day)
        })

        {:ok, context}
      end

      given_ "Dana opens a new dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she asks for a traffic chart without naming a range", context do
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
                      }
                    ]
                  })
              },
              completion_text: "Here's your traffic."
            )
          )
        )

        render_submit(context.view, "send_dashboard_chat", %{"message" => "Show me traffic"})
        await_dashboard_chat_completion(context.view)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "the chart covers the last 30 days ending yesterday", context do
        assert render(context.view) =~ "100"
        {:ok, context}
      end

      then_ "today's incomplete data is not included", context do
        refute render(context.view) =~ "107"
        {:ok, context}
      end
    end
  end
end
