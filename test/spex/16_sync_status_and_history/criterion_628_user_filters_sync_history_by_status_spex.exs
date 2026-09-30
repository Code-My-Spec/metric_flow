defmodule MetricFlowSpex.UserFiltersSyncHistoryByStatusSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User filters sync history by status", criterion: 628 do
    scenario "filtering by failed shows only failed entries" do
      given_(:user_logged_in_as_owner)

      given_ "an integration's sync history contains both successful and failed entries",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :success,
          records_synced: 10,
          completed_at: DateTime.utc_now()
        })

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :failed,
          records_synced: 0,
          error_message: "Sync failed",
          completed_at: DateTime.utc_now()
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they filter by failed", context do
        context.view
        |> element("[data-role='filter-failed']")
        |> render_click()

        {:ok, context}
      end

      then_ "only failed entries are shown", context do
        html = render(context.view)
        refute html =~ "badge-success"

        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed']"
               )

        {:ok, context}
      end
    end

    scenario "filtering by success shows only successful entries" do
      given_(:user_logged_in_as_owner)

      given_ "an integration's sync history contains both successful and failed entries",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :success,
          records_synced: 10,
          completed_at: DateTime.utc_now()
        })

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :failed,
          records_synced: 0,
          error_message: "Sync failed",
          completed_at: DateTime.utc_now()
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they filter by success", context do
        context.view
        |> element("[data-role='filter-success']")
        |> render_click()

        {:ok, context}
      end

      then_ "only successful entries are shown", context do
        refute has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed']"
               )

        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success']"
               )

        {:ok, context}
      end
    end
  end
end
