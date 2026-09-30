defmodule MetricFlowSpex.TemplateSelectedBeforeAnyDataHasSyncedShowsAnEmptyStateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Template selected before any data has synced shows an empty state", criterion: 776 do
    scenario "a user with no platform integrations selects a default template" do
      given_(:user_logged_in_as_owner)

      given_ "a default template exists and the user has no platform integrations synced yet",
             context do
        MetricFlowSpex.Fixtures.create_canned_dashboard!(
          context.owner_email,
          "Marketing Overview"
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select a default template", context do
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

      then_ "the dashboard renders with an empty or zero-state view rather than an error",
            context do
        assert has_element?(context.template_view, "[data-role='onboarding-prompt']")
        {:ok, context}
      end
    end
  end
end
