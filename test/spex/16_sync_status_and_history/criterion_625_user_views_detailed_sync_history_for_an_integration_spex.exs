defmodule MetricFlowSpex.UserViewsDetailedSyncHistoryForAnIntegrationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User views detailed sync history for an integration", criterion: 625 do
    scenario "an integration with more than 30 past syncs shows at least the last 30" do
      given_(:user_logged_in_as_owner)

      given_ "an integration has more than 30 past sync attempts", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        for i <- 1..35 do
          MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
            provider: :google_ads,
            status: :success,
            records_synced: i,
            completed_at: DateTime.add(DateTime.utc_now(), -i * 3600, :second)
          })
        end

        {:ok, context}
      end

      when_ "the user opens its sync history", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "at least the last 30 syncs are shown", context do
        count = context.view |> element("[data-role='sync-history']") |> has_element?()
        assert count

        entry_count =
          context.view
          |> render()
          |> Floki.parse_document!()
          |> Floki.find("[data-role='sync-history-entry']")
          |> length()

        assert entry_count >= 30
        {:ok, context}
      end
    end
  end
end
