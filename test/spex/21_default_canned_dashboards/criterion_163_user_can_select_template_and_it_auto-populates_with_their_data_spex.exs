defmodule MetricFlowSpex.UserCanSelectTemplateAndItAutoPopulatesWithTheirDataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can select template and it auto-populates with their data", criterion: 163 do
    scenario "a user with synced platform data selects a template and sees their own data" do
      given_(:user_logged_in_as_owner)

      given_ "a default template exists and the user has synced platform data", context do
        MetricFlowSpex.Fixtures.create_canned_dashboard!(
          context.owner_email,
          "Marketing Overview"
        )

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select the Marketing Overview template", context do
        dashboard_id =
          context.view
          |> element("[data-role='dashboard-card']", "Marketing Overview")
          |> render()
          |> then(fn html ->
            [_, id] = Regex.run(~r/data-dashboard-id="(\d+)"/, html)
            id
          end)

        {:ok, template_view, _html} = live(context.owner_conn, "/app/dashboards/#{dashboard_id}")
        {:ok, Map.put(context, :template_view, template_view)}
      end

      then_ "the dashboard auto-populates its charts and metrics using that user's own data",
            context do
        html = render(context.template_view)
        assert html =~ "clicks"
        assert has_element?(context.template_view, "[data-role='vega-lite-chart']")
        {:ok, context}
      end
    end
  end
end
