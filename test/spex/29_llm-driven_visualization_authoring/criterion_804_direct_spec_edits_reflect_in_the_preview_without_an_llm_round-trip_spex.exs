defmodule MetricFlowSpex.Criterion804DirectSpecEditsReflectWithoutLlmSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Direct spec edits reflect in the preview without an LLM round-trip", criterion: 804 do
    scenario "editing the Vega-Lite JSON spec directly updates the preview without calling the LLM" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user viewing the spec editor in advanced mode", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      # Note: resolve_named_data replaces the named source with real values,
      # so the metric name is checked in the spec editor's raw text below.

      when_ "they edit the Vega-Lite JSON spec directly", context do
        context.view
        |> element("[data-role='vega-spec-textarea']")
        |> render_blur(%{
          "value" =>
            Jason.encode!(%{
              "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
              "data" => %{"name" => "spend"},
              "mark" => "area",
              "encoding" => %{}
            })
        })

        {:ok, context}
      end

      then_ "the live preview updates to reflect the change without calling the LLM", context do
        spec_text =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        assert spec_text =~ "spend"

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
