defmodule MetricFlowSpex.Criterion854FewerThanFiveQualifyingCorrelationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Fewer than five qualifying correlations shows only what qualifies", criterion: 854 do
    scenario "only two positive correlations exceed the threshold and only those are shown" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "fewer than 5 positive correlations exceed the minimum threshold", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "qualifying_one",
          goal_metric_name: "revenue",
          coefficient: 0.5
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "qualifying_two",
          goal_metric_name: "revenue",
          coefficient: 0.4
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "below_threshold_one",
          goal_metric_name: "revenue",
          coefficient: 0.2
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "below_threshold_two",
          goal_metric_name: "revenue",
          coefficient: 0.1
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "Smart/AI mode displays results", context do
        {:ok, context}
      end

      then_ "only the qualifying correlations are shown rather than padding the list with weaker ones below the threshold", context do
        positive_count =
          context.view
          |> render()
          |> Floki.parse_document!()
          |> Floki.find("[data-role='top-positive-correlations'] [data-role='correlation-row']")
          |> length()

        assert positive_count == 2,
               "Expected exactly the 2 qualifying correlations, not padded with weaker ones, got #{positive_count}"

        refute has_element?(context.view, "[data-role='correlation-row'][data-metric='below_threshold_one']")
        refute has_element?(context.view, "[data-role='correlation-row'][data-metric='below_threshold_two']")

        {:ok, context}
      end
    end
  end
end
