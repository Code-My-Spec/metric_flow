defmodule MetricFlowSpex.Story75.Criterion1071Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1071 — Duplicating a dashboard copies its current blob and
  filters into a new dashboard with a new name, and nothing else (no
  chat history or versions from the original).
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana duplicates a dashboard to try a variation", criterion: 1071 do
    scenario "the copy keeps the charts and the filter but starts with no history" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana has a dashboard with a 90-day filter", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        Process.sleep(100)
        Application.delete_env(:metric_flow, :command_runner)

        view
        |> element("[data-role='filter-control'] form[phx-change]")
        |> render_change(%{"range" => "90"})

        {:ok, index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        [dashboard_id] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role^='edit-dashboard-']")
          |> Floki.attribute("data-role")
          |> Enum.map(&String.replace_prefix(&1, "edit-dashboard-", ""))

        {:ok, Map.merge(context, %{index_view: index_view, original_id: dashboard_id})}
      end

      when_ "she duplicates it", context do
        context.index_view
        |> element("[data-role='duplicate-dashboard-#{context.original_id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "a new dashboard exists with the same charts and the 90-day filter", context do
        html = render(context.index_view)

        new_ids =
          html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role^='edit-dashboard-']")
          |> Floki.attribute("data-role")
          |> Enum.map(&String.replace_prefix(&1, "edit-dashboard-", ""))

        assert new_id = Enum.find(new_ids, &(&1 != context.original_id))

        {:ok, copy_view, _copy_html} =
          live(context.owner_conn, ~p"/app/dashboards/#{new_id}/edit")

        assert has_element?(copy_view, "[data-role='visualization-card']")

        assert has_element?(
                 copy_view,
                 "[data-role='filter-control'] option[value='90'][selected]"
               )

        {:ok, Map.put(context, :copy_view, copy_view)}
      end

      then_ "it has no chat history or versions from the original", context do
        refute has_element?(context.copy_view, "[data-role='dashboard-chat-message']")
        {:ok, context}
      end
    end
  end
end
