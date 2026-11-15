defmodule MetricFlowSpex.Story75.Criterion1076Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1076 — Built-in dashboards are listed in a separate section
  from Dana's own.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana sees built-in dashboards apart from her own", criterion: 1076 do
    scenario "the list separates built-in dashboards from her own" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana has her own dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        await_dashboard_chat_completion(view)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      when_ "she opens the dashboards list", context do
        {:ok, index_view, _html} = live(context.owner_conn, ~p"/app/dashboards")
        {:ok, Map.put(context, :index_view, index_view)}
      end

      then_ "the built-in dashboards appear in their own section", context do
        html = render(context.index_view)

        built_in_cards =
          html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='canned-dashboards'] [data-role='dashboard-card']")

        assert built_in_cards != []

        assert Enum.all?(
                 built_in_cards,
                 &(Floki.attribute(&1, "data-built-in") == ["true"])
               )

        {:ok, context}
      end

      then_ "her own dashboards appear separately", context do
        own_cards =
          render(context.index_view)
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='user-dashboards'] [data-role='dashboard-card']")

        assert own_cards != []

        assert Enum.all?(
                 own_cards,
                 &(Floki.attribute(&1, "data-built-in") == ["false"])
               )

        {:ok, context}
      end
    end
  end
end
