defmodule MetricFlowSpex.Story74.Criterion1062Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1062 — Dana chooses Edit with agent and keeps refining: the
  earlier conversation is there beside the dashboard, and the next
  request changes it rather than starting over.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana chooses Edit with agent and keeps refining", criterion: 1062 do
    scenario "reopening via Edit with agent keeps the conversation and edits in place" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana built a dashboard by chat yesterday", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        Process.sleep(100)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, _index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        # Only a user's own dashboard card renders an edit-dashboard link --
        # the canned/built-in cards above it in the list only ever render
        # a View link -- so this is already scoped to the one just built,
        # without needing to pick it out from the built-ins by name or id.
        [edit_href | _] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("a[data-role^='edit-dashboard-']")
          |> Floki.attribute("href")

        show_href = String.replace_trailing(edit_href, "/edit", "")
        {:ok, Map.put(context, :show_href, show_href)}
      end

      when_ "she reopens it today and chooses Edit with agent", context do
        {:ok, show_view, _show_html} = live(context.owner_conn, context.show_href)

        [edit_href | _] =
          show_view
          |> render()
          |> Floki.parse_fragment!()
          |> Floki.find("a[data-role^='edit-dashboard-']")
          |> Floki.attribute("href")

        {:ok, edit_view, edit_html} = live(context.owner_conn, edit_href)
        {:ok, Map.merge(context, %{edit_view: edit_view, edit_html: edit_html})}
      end

      then_ "she sees the earlier conversation beside the dashboard", context do
        assert context.edit_html =~ "Show me impressions"
        assert has_element?(context.edit_view, "[data-role='dashboard-chat-message']")
        {:ok, context}
      end

      then_ "her next request changes the existing dashboard rather than starting over",
            context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_followup()
        )

        render_submit(context.edit_view, "send_dashboard_chat", %{
          "message" => "Add clicks as a second chart"
        })

        Process.sleep(100)
        Application.delete_env(:metric_flow, :command_runner)

        cards =
          context.edit_view
          |> render()
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='visualization-card']")

        assert length(cards) == 3
        {:ok, context}
      end
    end
  end
end
