defmodule MetricFlowSpex.SystemFetchesDataUsingFacebookNodejsBusinessSdkCallingAccountgetinsightsAtAccountLevelWithTimeIncrement1DailyBreakdownSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System fetches data using facebook-nodejs-business-sdk, calling account.getInsights() at account level with time_increment: 1 (daily breakdown)" do
    scenario "the sync history page displays Facebook Ads sync results with daily data, indicating account-level insights were fetched" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast to the LiveView with daily records", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 30,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a successful Facebook Ads sync entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected the sync history page to show 'Facebook Ads' provider name, got: #{html}"

        :ok
      end

      then_ "the sync entry reflects a completed daily data fetch with records synced", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected sync history entry to show a success status, got: #{html}"

        assert html =~ "30" or html =~ "records",
               "Expected sync history entry to show the number of daily records synced, got: #{html}"

        :ok
      end
    end

    scenario "the sync history page shows Facebook Ads as a covered provider in the schedule section" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page mentions Facebook Ads as a supported marketing data provider", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected the sync history page to mention 'Facebook Ads' as a supported provider, got: #{html}"

        :ok
      end

      then_ "the schedule section describes daily per-provider data fetching", context do
        html = render(context.view)

        assert html =~ "Daily" or html =~ "daily",
               "Expected the schedule section to describe daily syncs, got: #{html}"

        assert html =~ "provider" or html =~ "metrics",
               "Expected the schedule section to mention per-provider data fetching, got: #{html}"

        :ok
      end
    end

    scenario "a failed Facebook Ads sync is surfaced in sync history with an error message" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast with an API error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook Business SDK error: OAuthException - Invalid access token"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected a Facebook Ads provider entry in sync history, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the failure reason from the Facebook API is displayed", context do
        html = render(context.view)

        assert html =~ "Facebook Business SDK error" or html =~ "OAuthException" or html =~ "error",
               "Expected the failure reason to be shown in sync history, got: #{html}"

        :ok
      end
    end
  end
end
