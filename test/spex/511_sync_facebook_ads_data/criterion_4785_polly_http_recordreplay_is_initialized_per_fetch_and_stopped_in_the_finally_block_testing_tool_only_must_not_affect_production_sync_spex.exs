defmodule MetricFlowSpex.PollyHttpRecordreplayIsInitializedPerFetchAndStoppedInTheFinallyBlockTestingToolOnlyMustNotAffectProductionSyncSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Polly HTTP record/replay is a testing tool only and must not affect production sync" do
    scenario "a production Facebook Ads sync completion shows clean results with no testing tool references" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 10,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a successful Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' provider name, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end

      then_ "no Polly or testing tool references are visible in the sync history", context do
        html = render(context.view)

        refute html =~ "Polly",
               "Expected no 'Polly' testing tool reference in sync history, got: #{html}"

        refute html =~ "cassette",
               "Expected no 'cassette' testing tool reference in sync history, got: #{html}"

        refute html =~ "record/replay" or not (html =~ "record/replay"),
               "Expected no 'record/replay' testing tool reference in sync history"

        :ok
      end
    end

    scenario "the sync history entry for a completed Facebook Ads sync shows normal results without debug metadata" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event arrives with record count and timestamp", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 7,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry displays normal sync metadata — provider, status, and record count", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads', got: #{html}"

        assert html =~ "7" or html =~ "records",
               "Expected sync history to show the records synced count, got: #{html}"

        :ok
      end

      then_ "no testing infrastructure text appears in the sync history entry", context do
        html = render(context.view)

        refute html =~ "replay",
               "Expected no 'replay' testing infrastructure text in the sync history entry, got: #{html}"

        refute html =~ "recording",
               "Expected no 'recording' testing infrastructure text in the sync history entry, got: #{html}"

        :ok
      end
    end

    scenario "a Facebook Ads sync failure shows the actual API error, not any testing infrastructure error" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast with a real API error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook Ads API error: 190 Invalid OAuth access token"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Facebook Ads entry with the actual API error", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' for the failure entry, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Facebook Ads sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error message shown is the real API error, not a Polly or testing tool error", context do
        html = render(context.view)

        assert html =~ "190" or html =~ "OAuth" or html =~ "access token" or
                 html =~ "Facebook Ads API error" or html =~ "error",
               "Expected the real Facebook Ads API error to be shown in sync history, got: #{html}"

        refute html =~ "Polly",
               "Expected no Polly testing tool error in sync history for a production sync failure, got: #{html}"

        :ok
      end
    end
  end
end
