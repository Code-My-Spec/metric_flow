defmodule MetricFlowSpex.Criterion243DirectSpecEditReflectsWithoutLlmSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can edit the Vega-Lite spec directly in the spec editor drawer; changes are reflected in the live preview without requiring an LLM round-trip",
    criterion: 243 do
    scenario "editing the spec textarea updates the preview without calling the LLM" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "user opens the visualization editor and spec panel", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user edits the Vega-Lite spec directly", context do
        # No req_http_options/plug is configured here -- if this reached the LLM
        # it would fail against the real network, proving the edit is local-only.
        context.view
        |> element("[data-role='vega-spec-textarea']")
        |> render_blur(%{
          "value" =>
            Jason.encode!(%{
              "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
              "data" => %{"name" => "clicks"},
              "mark" => "bar",
              "encoding" => %{}
            })
        })

        {:ok, context}
      end

      then_ "the live preview reflects the change immediately", context do
        assert has_element?(context.view, "[data-role='vega-lite-chart']")

        # The chart's own resolved data-spec no longer names the metric --
        # resolve_named_data replaces the named source with real values --
        # so the metric name is checked in the spec editor's raw text instead.
        spec_text =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        assert spec_text =~ "clicks"

        chart_html =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert chart_html =~ "&quot;values&quot;"
        {:ok, context}
      end
    end
  end
end
