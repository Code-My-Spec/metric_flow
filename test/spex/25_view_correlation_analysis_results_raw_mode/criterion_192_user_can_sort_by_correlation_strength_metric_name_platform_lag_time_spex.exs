defmodule MetricFlowSpex.Criterion192UserCanSortByCorrelationStrengthMetricNamePlatformLagTimeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can sort by: correlation strength, metric name, platform, lag time", criterion: 192 do
    scenario "a user sorts the correlation list by each available column" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "several correlations differing in strength, name, platform, and lag", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "zzz_metric",
          goal_metric_name: "revenue",
          coefficient: 0.4,
          optimal_lag: 10,
          provider: :google_ads
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "aaa_metric",
          goal_metric_name: "revenue",
          coefficient: 0.7,
          optimal_lag: 2,
          provider: :quickbooks
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they sort by correlation strength", context do
        context.view
        |> element("[data-sort-col='coefficient']")
        |> render_click()

        {:ok, context}
      end

      then_ "the list is sortable by correlation strength", context do
        assert has_element?(context.view, "[data-sort-col='coefficient'][data-sort-active='true']")
        {:ok, context}
      end

      when_ "they sort by metric name", context do
        context.view
        |> element("[data-sort-col='metric_name']")
        |> render_click()

        {:ok, context}
      end

      then_ "the list is sortable by metric name", context do
        assert has_element?(context.view, "[data-sort-col='metric_name'][data-sort-active='true']")
        {:ok, context}
      end

      when_ "they sort by platform", context do
        context.view
        |> element("[data-sort-col='platform']")
        |> render_click()

        {:ok, context}
      end

      then_ "the list is sortable by platform", context do
        assert has_element?(context.view, "[data-sort-col='platform'][data-sort-active='true']")
        {:ok, context}
      end

      when_ "they sort by lag time", context do
        context.view
        |> element("[data-sort-col='lag']")
        |> render_click()

        {:ok, context}
      end

      then_ "the list is sortable by lag time", context do
        assert has_element?(context.view, "[data-sort-col='lag'][data-sort-active='true']")
        {:ok, context}
      end
    end
  end
end
