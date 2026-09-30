defmodule MetricFlowSpex.UserBrowsesAvailableDefaultTemplatesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User browses available default templates", criterion: 774 do
    scenario "a user opening the dashboards section sees the default templates" do
      given_(:user_logged_in_as_owner)

      given_ "default dashboard templates exist", context do
        for name <- ["Marketing Overview", "Revenue Analysis", "Platform Comparison"] do
          MetricFlowSpex.Fixtures.create_canned_dashboard!(context.owner_email, name)
        end

        {:ok, context}
      end

      when_ "they view the list of available templates", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see default templates including Marketing Overview, Revenue Analysis, and Platform Comparison",
            context do
        html = render(context.view)
        assert html =~ "Marketing Overview"
        assert html =~ "Revenue Analysis"
        assert html =~ "Platform Comparison"
        {:ok, context}
      end
    end
  end
end
