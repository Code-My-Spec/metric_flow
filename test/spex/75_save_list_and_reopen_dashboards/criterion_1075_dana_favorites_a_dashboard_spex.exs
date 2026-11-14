defmodule MetricFlowSpex.Story75.Criterion1075Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1075 — Dana can mark a dashboard as a favorite and remove
  the mark.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana favorites a dashboard", criterion: 1075 do
    scenario "favoriting moves it to the top, and unfavoriting is reversible" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana has two dashboards, neither a favorite", context do
        for _ <- 1..2 do
          {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

          Application.put_env(
            :metric_flow,
            :command_runner,
            MetricFlowTest.DashboardBuilderStub.generate_initial()
          )

          render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
          Process.sleep(100)
          Application.delete_env(:metric_flow, :command_runner)
          Process.sleep(10)
        end

        {:ok, index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        card_ids =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='user-dashboards'] [data-role='dashboard-card']")
          |> Floki.attribute("data-dashboard-id")

        [_newest, oldest] = card_ids
        {:ok, Map.merge(context, %{index_view: index_view, target_id: oldest})}
      end

      when_ "she marks the older one as a favorite", context do
        context.index_view
        |> element("[data-role='favorite-dashboard-#{context.target_id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "it moves to the top of her list", context do
        [first_id | _] =
          render(context.index_view)
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='user-dashboards'] [data-role='dashboard-card']")
          |> Floki.attribute("data-dashboard-id")

        assert first_id == context.target_id
        {:ok, context}
      end

      then_ "she can unmark it later", context do
        context.index_view
        |> element("[data-role='favorite-dashboard-#{context.target_id}']")
        |> render_click()

        refute has_element?(
                 context.index_view,
                 "[data-role='favorite-dashboard-#{context.target_id}'].text-warning"
               )

        {:ok, context}
      end
    end
  end
end
