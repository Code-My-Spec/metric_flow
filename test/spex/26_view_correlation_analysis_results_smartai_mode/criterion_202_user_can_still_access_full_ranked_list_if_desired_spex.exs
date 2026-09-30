defmodule MetricFlowSpex.Criterion202UserCanAccessFullRankedListSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can still access full ranked list if desired", criterion: 202 do
    scenario "a user viewing curated Smart mode results switches to the full ranked list" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing the curated Smart/AI results", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.55,
          provider: :google_ads
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they choose to see the full ranked list", context do
        context.view
        |> element("[data-role='mode-raw']")
        |> render_click()

        {:ok, context}
      end

      then_ "they can access the complete, uncurated ranking of correlations", context do
        assert has_element?(context.view, "[data-role='correlations-table']") or
                 has_element?(context.view, "table"),
               "Expected the full uncurated ranked list to be shown"

        refute has_element?(context.view, "[data-role='smart-mode']")

        {:ok, context}
      end
    end
  end
end
