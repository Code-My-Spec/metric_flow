defmodule MetricFlowSpex.UserSelectsADateRangeOptionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects a date range option", criterion: 750 do
    scenario "a client selects the last 90 days option and the dashboard shows data for that range" do
      given_(:user_logged_in_as_owner)

      given_ "a client is viewing the dashboard", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select last 90 days", context do
        context.view
        |> element("[data-role='date-range-filter'] button[phx-value-range='last_90_days']")
        |> render_click()

        {:ok, context}
      end

      then_ "the dashboard shows data for that range", context do
        assert has_element?(
                 context.view,
                 "[data-role='date-range-filter'] button.btn-primary[phx-value-range='last_90_days']"
               )

        {:ok, context}
      end
    end
  end
end
