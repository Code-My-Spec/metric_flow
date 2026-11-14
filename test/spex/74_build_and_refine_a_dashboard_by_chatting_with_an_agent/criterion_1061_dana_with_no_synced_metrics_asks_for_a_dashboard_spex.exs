defmodule MetricFlowSpex.Story74.Criterion1061Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1061 — Dana with no synced metrics asks for a dashboard: the
  agent says no metrics are available yet, offers a link to connect a
  platform, and nothing misleading appears on the dashboard.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana with no synced metrics asks for a dashboard", criterion: 1061 do
    scenario "the agent points Dana at Integrations instead of building anything" do
      given_(:user_logged_in_as_owner)

      given_ "Dana has no synced metrics and opens a new dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she asks the agent for a traffic dashboard", context do
        render_submit(context.view, "send_dashboard_chat", %{
          "message" => "Show me a traffic dashboard"
        })

        {:ok, context}
      end

      then_ "the agent says no metrics are available yet", context do
        assert render(context.view) =~ "No metrics are available yet"
        {:ok, context}
      end

      then_ "it offers a link to connect a platform", context do
        assert has_element?(context.view, "a[href='/app/integrations']")
        {:ok, context}
      end

      then_ "nothing misleading appears on the dashboard", context do
        refute has_element?(context.view, "[data-role='visualization-card']")
        refute has_element?(context.view, "[data-role='stat-tile-value']")
        {:ok, context}
      end
    end
  end
end
