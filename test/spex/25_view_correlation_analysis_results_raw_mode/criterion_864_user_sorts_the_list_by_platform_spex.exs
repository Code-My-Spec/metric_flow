defmodule MetricFlowSpex.Criterion864UserSortsTheListByPlatformSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User sorts the list by platform", criterion: 864 do
    scenario "a user sorts the Raw mode list by platform" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the Raw mode correlation list", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ads_metric",
          goal_metric_name: "revenue",
          coefficient: 0.5,
          provider: :google_ads
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "books_metric",
          goal_metric_name: "revenue",
          coefficient: 0.4,
          provider: :quickbooks
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a user sorts by platform", context do
        context.view
        |> element("[data-sort-col='platform']")
        |> render_click()

        {:ok, context}
      end

      then_ "the list reorders accordingly", context do
        assert has_element?(context.view, "[data-sort-col='platform'][data-sort-active='true']")

        html = render(context.view)
        parsed = Floki.parse_document!(html)

        names =
          parsed
          |> Floki.find("[data-role='correlation-row']")
          |> Enum.map(fn row -> row |> Floki.attribute("data-metric") |> List.first() end)

        assert names == ["books_metric", "ads_metric"],
               "Expected the list to reorder by platform, got: #{inspect(names)}"

        {:ok, context}
      end
    end
  end
end
