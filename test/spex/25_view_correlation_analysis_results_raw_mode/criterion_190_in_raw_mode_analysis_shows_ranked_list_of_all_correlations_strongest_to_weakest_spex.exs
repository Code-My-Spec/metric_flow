defmodule MetricFlowSpex.Criterion190InRawModeAnalysisShowsRankedListOfAllCorrelationsStrongestToWeakestSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "In Raw mode: analysis shows ranked list of ALL correlations (strongest to weakest)",
    criterion: 190 do
    scenario "Raw mode lists every calculated correlation ordered from strongest to weakest" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "correlations of varying strength have been calculated", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "weakest",
          goal_metric_name: "revenue",
          coefficient: 0.35
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "strongest",
          goal_metric_name: "revenue",
          coefficient: 0.85
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "middle",
          goal_metric_name: "revenue",
          coefficient: 0.6
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a user views Raw mode", context do
        {:ok, context}
      end

      then_ "all correlations are shown, ranked from strongest to weakest", context do
        html = render(context.view)
        parsed = Floki.parse_document!(html)

        names =
          parsed
          |> Floki.find("[data-role='correlation-row']")
          |> Enum.map(fn row -> row |> Floki.attribute("data-metric") |> List.first() end)

        assert names == ["strongest", "middle", "weakest"],
               "Expected every correlation shown ranked strongest to weakest, got: #{inspect(names)}"

        {:ok, context}
      end
    end
  end
end
