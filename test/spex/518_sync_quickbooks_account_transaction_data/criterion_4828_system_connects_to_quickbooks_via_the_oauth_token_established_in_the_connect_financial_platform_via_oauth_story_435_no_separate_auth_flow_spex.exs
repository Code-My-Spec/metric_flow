defmodule MetricFlowSpex.QuickBooksConnectsViaOAuthTokenNoSeparateAuthFlowSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System connects to QuickBooks via OAuth token from Story 435 — no separate auth flow" do
    scenario "successful QuickBooks sync shows in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completes successfully using the stored OAuth token", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 42,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a QuickBooks entry with success status", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry, got: #{html}"

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the QuickBooks sync entry to show success status, got: #{html}"

        :ok
      end
    end

    scenario "the connect page shows QuickBooks under existing OAuth with no separate flow" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "QuickBooks is listed as a connectable platform", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the connect page to list QuickBooks as a platform, got: #{html}"

        :ok
      end

      then_ "QuickBooks does not show a separate auth flow distinct from the standard OAuth button", context do
        html = render(context.view)

        refute html =~ "Separate QuickBooks Auth" or html =~ "secondary_auth",
               "Expected QuickBooks to use the standard OAuth flow, not a separate auth flow, got: #{html}"

        :ok
      end
    end

    scenario "failed QuickBooks sync due to expired token shows auth error in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync fails because the OAuth token has expired", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks OAuth token expired: 401 Unauthorized — token refresh required"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed QuickBooks entry", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry for the token failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the expired-token failure to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the auth error details are surfaced in the failed sync entry", context do
        html = render(context.view)

        assert html =~ "401" or html =~ "Unauthorized" or html =~ "token" or
                 html =~ "expired" or html =~ "OAuth",
               "Expected the OAuth token error to be surfaced in the sync history, got: #{html}"

        :ok
      end

      then_ "the failed entry has a sync-error element with the auth error", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the auth error details"

        :ok
      end
    end
  end
end
