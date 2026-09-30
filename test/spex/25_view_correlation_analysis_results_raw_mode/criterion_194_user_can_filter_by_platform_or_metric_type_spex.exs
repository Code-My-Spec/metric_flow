defmodule MetricFlowSpex.Criterion194UserCanFilterByPlatformOrMetricTypeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can filter by platform or metric type", criterion: 194 do
    scenario "a user filters the correlation list to a single platform" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "correlations from more than one platform", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ads_metric",
          goal_metric_name: "revenue",
          coefficient: 0.5,
          provider: :google_ads
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "books_metric",
          goal_metric_name: "revenue",
          coefficient: 0.45,
          provider: :quickbooks
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they filter by a single platform", context do
        context.view
        |> element("[phx-click='filter_platform'][phx-value-platform='google_ads']")
        |> render_click()

        {:ok, context}
      end

      then_ "only correlations for metrics from that platform are shown", context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='ads_metric']")
        refute has_element?(context.view, "[data-role='correlation-row'][data-metric='books_metric']")
        {:ok, context}
      end
    end
  end
end
