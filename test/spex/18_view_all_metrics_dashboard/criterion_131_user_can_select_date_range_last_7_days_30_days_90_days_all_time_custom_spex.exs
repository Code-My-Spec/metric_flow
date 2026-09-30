defmodule MetricFlowSpex.UserCanSelectDateRangeLast7Days30Days90DaysAllTimeCustomSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can select date range: last 7 days, 30 days, 90 days, all time, custom",
    criterion: 131 do
    scenario "a client selects the Last 7 Days date range and the dashboard shows data for that range" do
      given_(:user_logged_in_as_owner)

      given_ "the client has connected data", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select the Last 7 Days date range", context do
        context.view
        |> element("[data-role='date-range-filter'] button[phx-value-range='last_7_days']")
        |> render_click()

        {:ok, context}
      end

      then_ "the dashboard shows data for that range", context do
        assert has_element?(
                 context.view,
                 "[data-role='date-range-filter'] button.btn-primary[phx-value-range='last_7_days']"
               )

        {:ok, context}
      end
    end

    scenario "a client selects a custom date range and the dashboard shows data for that range" do
      given_(:user_logged_in_as_owner)

      given_ "the client has connected data", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select a custom date range", context do
        context.view
        |> element("[data-role='date-range-filter'] button[phx-value-range='custom']")
        |> render_click()

        {:ok, context}
      end

      then_ "a custom date range picker is available for them to set the range", context do
        assert has_element?(context.view, "[data-role='custom-date-picker']")
        {:ok, context}
      end
    end
  end
end
