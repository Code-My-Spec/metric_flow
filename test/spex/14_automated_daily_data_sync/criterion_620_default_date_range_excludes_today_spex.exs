defmodule MetricFlowSpex.DefaultDateRangeExcludesTodaySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Default date range excludes today", criterion: 620 do
    scenario "today's data has not yet fully synced, so the default range excludes it" do
      given_ :owner_with_integrations

      when_ "today's data has not yet fully synced", context do
        {:ok, view, html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the default range excludes today so it doesn't show a false zero", context do
        today = Date.utc_today() |> Date.to_iso8601()
        yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()

        assert context.html =~ yesterday
        refute has_element?(context.view, "[data-role='date-range']", today)
        {:ok, context}
      end
    end
  end
end
