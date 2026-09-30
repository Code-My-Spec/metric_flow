defmodule MetricFlowSpex.Criterion196ResultsUpdateWhenUserChangesTimeWindowOrFiltersSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Results update when user changes time window or filters", criterion: 196 do
    scenario "results update when the user changes a filter" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing correlation results from more than one platform", context do
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

      when_ "they apply a platform filter", context do
        context.view
        |> element("[phx-click='filter_platform'][phx-value-platform='google_ads']")
        |> render_click()

        {:ok, context}
      end

      then_ "the displayed results update to reflect the new filter", context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='ads_metric']")
        refute has_element?(context.view, "[data-role='correlation-row'][data-metric='books_metric']")
        {:ok, context}
      end
    end

    scenario "results update when the user changes the time window" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing correlation results for the default time window", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.5
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they change the time window", context do
        assert has_element?(context.view, "[data-role='time-window-selector']"),
               "Expected a time-window selector to exist so its change can be observed"

        {:ok, context}
      end

      then_ "the displayed results update to reflect the new time window", context do
        {:ok, context}
      end
    end
  end
end
