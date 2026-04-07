defmodule MetricFlowSpex.Criterion5052DirectSpecEditWithoutLlmSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can edit Vega-Lite spec directly without an LLM round-trip" do
    scenario "the visualization editor allows direct spec editing with live preview" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user is on the visualization editor with a metric selected", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        # Open spec editor
        view
        |> element("[data-role='toggle-spec-editor']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user edits the spec JSON directly in the textarea", context do
        custom_spec =
          Jason.encode!(%{
            "mark" => "bar",
            "encoding" => %{
              "x" => %{"field" => "date", "type" => "temporal"},
              "y" => %{"field" => "value", "type" => "quantitative"}
            },
            "data" => %{
              "values" => [
                %{"date" => "2026-01-01", "value" => 42},
                %{"date" => "2026-01-02", "value" => 58}
              ]
            },
            "title" => "impressions"
          })

        context.view
        |> element("[data-role='vega-spec-textarea']")
        |> render_blur(%{"value" => custom_spec})

        {:ok, context}
      end

      then_ "the chart preview updates without any LLM call", context do
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        refute has_element?(context.view, ".text-error")
        :ok
      end
    end
  end
end
