defmodule MetricFlowSpex.FailedSyncsAreHighlightedWithErrorDetailsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Failed syncs are highlighted with error details" do
    scenario "a failed sync entry shows a visual error badge" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure arrives for the Google integration", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Authentication token expired"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the failed entry is highlighted with an error badge", context do
        assert has_element?(context.view, ".badge-error"),
               "Expected a badge-error element to visually highlight the failed sync"

        assert render(context.view) =~ "Failed",
               "Expected the failed sync to show a 'Failed' badge text"

        :ok
      end
    end

    scenario "a failed sync entry shows the error reason details" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure arrives with a specific error reason", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Rate limit exceeded: 429 Too Many Requests"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the error details displayed on the page", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a data-role='sync-error' element to surface the error details"

        html = render(context.view)

        assert html =~ "Rate limit exceeded",
               "Expected the error reason text to be visible to the user, got: #{html}"

        :ok
      end
    end

    scenario "failed entries are visually distinct from successful entries" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync and a failed sync both arrive", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 150
        }})

        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Connection refused: unable to reach API endpoint"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the failed entry shows a red error badge while the success entry shows a green badge", context do
        assert has_element?(context.view, "[data-status='failed'] .badge-error"),
               "Expected the failed entry to have a badge-error inside the data-status='failed' element"

        assert has_element?(context.view, "[data-status='success'] .badge-success"),
               "Expected the success entry to have a badge-success inside the data-status='success' element"

        :ok
      end
    end

    scenario "failed sync entries show the provider name alongside error details" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync fails with a permission error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Insufficient permissions to access ad account"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the error details linked to the Facebook Ads provider", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected the failed entry to identify the Facebook Ads provider, got: #{html}"

        assert html =~ "Insufficient permissions",
               "Expected the failure reason to be displayed alongside the provider name, got: #{html}"

        assert has_element?(context.view, "[data-role='sync-provider']"),
               "Expected a data-role='sync-provider' element to identify which provider failed"

        :ok
      end
    end
  end
end
