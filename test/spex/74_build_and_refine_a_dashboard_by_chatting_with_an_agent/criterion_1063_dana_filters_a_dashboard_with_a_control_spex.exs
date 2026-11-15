defmodule MetricFlowSpex.Story74.Criterion1063Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1063 — Dana filters a dashboard with a control: picking a
  platform re-queries her synced metrics for that platform only, and
  writes nothing to any external system.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana filters a dashboard with a platform control", criterion: 1063 do
    scenario "picking Google Ads in the control re-queries metrics for that platform only" do
      given_(:user_logged_in_as_owner)

      given_ "Dana has synced metrics from two platforms", context do
        for {provider, value} <- [{:google_ads, 100.0}, {:facebook_ads, 9999.0}] do
          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            provider: provider,
            metric_name: "impressions",
            value: value
          })
        end

        {:ok, context}
      end

      given_ "Dana has a dashboard with a platform filter control", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        await_dashboard_chat_completion(view)
        Application.delete_env(:metric_flow, :command_runner)

        assert has_element?(view, "[data-role='platform-filter']")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Dana picks Google Ads in the control", context do
        context.view
        |> element("[data-role='platform-filter'] [phx-value-platform='google_ads']")
        |> render_click()

        {:ok, context}
      end

      then_ "the charts re-query her synced metrics for that platform only", context do
        html = render(context.view)
        assert html =~ "100"
        refute html =~ "9,999"
        refute html =~ "10,099"
        {:ok, context}
      end

      then_ "nothing is written to any external system", context do
        refute has_element?(context.view, "[data-role='dashboard-chat-error']")
        {:ok, context}
      end
    end
  end
end
