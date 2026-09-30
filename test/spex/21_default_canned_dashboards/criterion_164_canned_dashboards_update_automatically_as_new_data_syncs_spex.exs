defmodule MetricFlowSpex.Criterion164CannedDashboardsUpdateAutomaticallyAsNewDataSyncsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Canned dashboards update automatically as new data syncs", criterion: 164 do
    scenario "new platform data syncs in while a canned dashboard is already open" do
      given_(:user_logged_in_as_owner)

      given_ "a canned dashboard is already populated with a user's data", context do
        MetricFlowSpex.Fixtures.create_canned_dashboard!(
          context.owner_email,
          "Marketing Overview"
        )

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 10.0
        })

        dashboard_id =
          context.owner_conn
          |> live("/app/dashboards")
          |> then(fn {:ok, view, _html} -> view end)
          |> element("[data-role='dashboard-card']", "Marketing Overview")
          |> render()
          |> then(fn html ->
            [_, id] = Regex.run(~r/data-dashboard-id="(\d+)"/, html)
            id
          end)

        {:ok, template_view, _html} = live(context.owner_conn, "/app/dashboards/#{dashboard_id}")
        assert render(template_view) =~ "10"

        {:ok, Map.put(context, :template_view, template_view)}
      end

      when_ "new data syncs in", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "conversions",
          value: 77.0
        })

        MetricFlowSpex.Fixtures.broadcast_sync_completed(context.owner_email, :google_ads)
        render(context.template_view)

        {:ok, context}
      end

      then_ "the dashboard updates automatically without manual refresh or rebuild", context do
        html = render(context.template_view)

        assert html =~ "conversions" and html =~ "77",
               "Expected the already-open dashboard to pick up newly synced data on its own, " <>
                 "got: #{html}"

        {:ok, context}
      end
    end
  end
end
