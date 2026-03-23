defmodule MetricFlowSpex.SmartModeTop5PositiveNegativeCorrelationsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "In Smart/AI mode: analysis shows top 5 positive and top 5 negative correlations" do
    scenario "user switches to Smart mode and sees top positive and negative correlations" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user switches to Smart mode", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      then_ "Smart mode panel is visible", context do
        assert has_element?(context.view, "[data-role='smart-mode']"),
               "Expected smart-mode panel to be rendered"

        :ok
      end

      then_ "the analysis shows a section for top positive correlations", context do
        html = render(context.view)

        assert html =~ "positive" or
                 has_element?(context.view, "[data-role='top-positive-correlations']"),
               "Expected top positive correlations section. Got: #{html}"

        :ok
      end

      then_ "the analysis shows a section for top negative correlations", context do
        html = render(context.view)

        assert html =~ "negative" or
                 has_element?(context.view, "[data-role='top-negative-correlations']"),
               "Expected top negative correlations section. Got: #{html}"

        :ok
      end

      then_ "no more than 5 positive correlations are shown", context do
        positive_count =
          context.view
          |> render()
          |> then(fn html ->
            Floki.parse_document!(html)
            |> Floki.find("[data-role='top-positive-correlations'] [data-role='correlation-row']")
            |> length()
          end)

        assert positive_count <= 5,
               "Expected at most 5 positive correlations in Smart mode, got #{positive_count}"

        :ok
      end

      then_ "no more than 5 negative correlations are shown", context do
        negative_count =
          context.view
          |> render()
          |> then(fn html ->
            Floki.parse_document!(html)
            |> Floki.find("[data-role='top-negative-correlations'] [data-role='correlation-row']")
            |> length()
          end)

        assert negative_count <= 5,
               "Expected at most 5 negative correlations in Smart mode, got #{negative_count}"

        :ok
      end
    end
  end
end
