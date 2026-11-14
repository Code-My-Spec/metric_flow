defmodule MetricFlowSpex.Story75.Criterion1073Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1073 — The dashboards list shows Dana's own dashboards with
  favorites first, then by last modified, and she can search by name.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana searches her dashboards by name", criterion: 1073 do
    scenario "favorites sort first and a search narrows the list" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana has dashboards 'Monday review' (favorite), 'Ad spend' and 'Traffic'",
             context do
        for name <- ["Traffic", "Ad spend", "Monday review"] do
          {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

          Application.put_env(
            :metric_flow,
            :command_runner,
            MetricFlowTest.DashboardBuilderStub.generate_initial()
          )

          render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
          Process.sleep(100)
          Application.delete_env(:metric_flow, :command_runner)

          {:ok, index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

          newest_id =
            index_html
            |> Floki.parse_fragment!()
            |> Floki.find("[data-role^='rename-dashboard-']")
            |> Floki.attribute("phx-value-id")
            |> List.first()

          index_view
          |> element("[data-role='rename-dashboard-#{newest_id}']")
          |> render_click()

          index_view
          |> form("[data-role='rename-form-#{newest_id}'] form", %{"name" => name})
          |> render_submit()

          Process.sleep(10)
        end

        {:ok, index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        [favorite_id] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='dashboard-card']")
          |> Enum.filter(&(Floki.text(&1) =~ "Monday review"))
          |> Enum.flat_map(&Floki.attribute(&1, "data-dashboard-id"))

        index_view
        |> element("[data-role='favorite-dashboard-#{favorite_id}']")
        |> render_click()

        {:ok, Map.put(context, :index_view, index_view)}
      end

      when_ "she opens the list", context do
        {:ok, context}
      end

      then_ "'Monday review' appears first, then the others by last modified", context do
        names =
          render(context.index_view)
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='dashboard-card'][data-built-in='false']")
          |> Enum.map(&(Floki.find(&1, "p.font-semibold") |> Floki.text()))

        assert names == ["Monday review", "Ad spend", "Traffic"]
        {:ok, context}
      end

      then_ "searching 'ad' shows only 'Ad spend'", context do
        context.index_view
        |> form("[data-role='dashboard-search'] form", %{"query" => "ad"})
        |> render_change()

        names =
          render(context.index_view)
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='dashboard-card'][data-built-in='false']")
          |> Enum.map(&(Floki.find(&1, "p.font-semibold") |> Floki.text()))

        assert names == ["Ad spend"]
        {:ok, context}
      end
    end
  end
end
