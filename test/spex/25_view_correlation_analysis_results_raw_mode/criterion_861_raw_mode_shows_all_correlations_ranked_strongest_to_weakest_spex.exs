defmodule MetricFlowSpex.Criterion861RawModeShowsAllCorrelationsRankedStrongestToWeakestSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Raw mode shows all correlations ranked strongest to weakest", criterion: 861 do
    scenario "correlations calculated for a goal metric are shown ranked in Raw mode" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "correlations have been calculated for a goal metric", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "weakest",
          goal_metric_name: "revenue",
          coefficient: 0.3
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "strongest",
          goal_metric_name: "revenue",
          coefficient: 0.9
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a user views Raw mode", context do
        {:ok, context}
      end

      then_ "they see every calculated correlation ranked from strongest to weakest", context do
        html = render(context.view)
        parsed = Floki.parse_document!(html)

        names =
          parsed
          |> Floki.find("[data-role='correlation-row']")
          |> Enum.map(fn row -> row |> Floki.attribute("data-metric") |> List.first() end)

        assert names == ["strongest", "weakest"],
               "Expected correlations ranked strongest to weakest, got: #{inspect(names)}"

        {:ok, context}
      end
    end
  end
end
