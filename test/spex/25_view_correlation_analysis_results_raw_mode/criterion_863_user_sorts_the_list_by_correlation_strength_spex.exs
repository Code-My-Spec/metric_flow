defmodule MetricFlowSpex.Criterion863UserSortsTheListByCorrelationStrengthSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User sorts the list by correlation strength", criterion: 863 do
    scenario "a user sorts the Raw mode list by correlation strength" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the Raw mode correlation list", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "weak",
          goal_metric_name: "revenue",
          coefficient: 0.3
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "strong",
          goal_metric_name: "revenue",
          coefficient: 0.8
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a user sorts by correlation strength", context do
        # The default sort is already coefficient/desc, so one click toggles
        # it to ascending -- weakest first.
        context.view
        |> element("[data-sort-col='coefficient']")
        |> render_click()

        {:ok, context}
      end

      then_ "the list reorders accordingly", context do
        html = render(context.view)
        parsed = Floki.parse_document!(html)

        names =
          parsed
          |> Floki.find("[data-role='correlation-row']")
          |> Enum.map(fn row -> row |> Floki.attribute("data-metric") |> List.first() end)

        assert names == ["weak", "strong"],
               "Expected the list to reorder by ascending correlation strength after toggling sort, got: #{inspect(names)}"

        {:ok, context}
      end
    end
  end
end
