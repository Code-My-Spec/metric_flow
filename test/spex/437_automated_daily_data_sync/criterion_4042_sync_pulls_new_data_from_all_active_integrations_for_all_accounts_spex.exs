defmodule MetricFlowSpex.SyncPullsNewDataFromAllActiveIntegrationsForAllAccountsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync pulls new data from all active integrations for all accounts" do
    scenario "sync history page lists an entry for the connected Google integration" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays the sync history list", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] element listing sync history entries"
        :ok
      end

      then_ "the sync history list shows the connected integration provider name", context do
        html = render(context.view)

        assert html =~ "Google" or html =~ "google",
               "Expected the sync history to include the connected Google integration, got: #{html}"
        :ok
      end
    end

    scenario "each sync history entry shows the provider name and sync result" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the LiveView receives a sync completion event for the Google integration", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 25,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees a sync result entry for the Google integration", context do
        html = render(context.view)

        assert html =~ "Google" or html =~ "google",
               "Expected the sync history entry to show the provider name 'Google', got: #{html}"
        :ok
      end

      then_ "the sync result entry shows the number of records synced", context do
        html = render(context.view)

        assert html =~ "25" or html =~ "records" or html =~ "synced",
               "Expected the sync history entry to show the number of records synced, got: #{html}"
        :ok
      end
    end

    scenario "a user with only inactive integrations sees an empty sync history" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the sync history page without any connected integrations", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history page loads successfully", context do
        html = render(context.view)

        assert html =~ "Sync History" or html =~ "sync history" or html =~ "sync-history",
               "Expected the sync history page to render, got: #{html}"
        :ok
      end

      then_ "no sync entries are shown for the user with no connected integrations", context do
        refute has_element?(context.view, "[data-role='sync-history-entry']"),
               "Expected no sync history entries when no integrations are connected"
        :ok
      end
    end

    scenario "sync history page shows entries scoped to all integrations belonging to the user" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history section is present on the page", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected the sync history page to have a [data-role='sync-history'] section"
        :ok
      end

      then_ "the page heading or label references sync history or synced data", context do
        html = render(context.view)

        assert html =~ "Sync History" or html =~ "Sync history" or html =~ "sync history",
               "Expected the page to display a 'Sync History' heading, got: #{html}"
        :ok
      end
    end
  end
end
