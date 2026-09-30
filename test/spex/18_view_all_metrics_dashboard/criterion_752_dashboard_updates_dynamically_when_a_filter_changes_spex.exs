defmodule MetricFlowSpex.DashboardUpdatesDynamicallyWhenAFilterChangesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Dashboard updates dynamically when a filter changes", criterion: 752 do
    scenario "a client changes a filter and the dashboard's data updates without a full page reload" do
      given_(:user_logged_in_as_owner)

      given_ "a client is viewing the dashboard with data from two platforms", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :quickbooks,
          metric_name: "revenue",
          value: 500.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        assert render(view) =~ "revenue"
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they change a filter", context do
        html =
          context.view
          |> element("[data-role='platform-filter'] button[phx-value-platform='google_ads']")
          |> render_click()

        {:ok, Map.put(context, :updated_html, html)}
      end

      then_ "the dashboard's data updates without a full page reload", context do
        assert context.updated_html =~ "clicks"
        refute context.updated_html =~ "revenue"
        assert Process.alive?(context.view.pid)
        {:ok, context}
      end
    end
  end
end
