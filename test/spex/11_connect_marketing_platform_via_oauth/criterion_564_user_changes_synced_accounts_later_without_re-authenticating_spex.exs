defmodule MetricFlowSpex.UserChangesSyncedAccountsLaterWithoutReAuthenticatingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User changes synced accounts later without re-authenticating", criterion: 564 do
    scenario "Dana changes which Google Ads accounts sync without re-authenticating" do
      given_ :owner_with_google_ads_integration

      given_ "Dana is on the account selection page having already selected accounts to sync", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_analytics/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she changes which accounts sync and saves the new selection", context do
        {:ok, view, html} =
          context.view
          |> form("[data-role='account-selection']", %{"manual_property_id" => "999888777"})
          |> render_submit()
          |> follow_redirect(context.owner_conn)

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the change is saved without requiring her to authenticate again", context do
        assert context.html =~ "saved successfully"
        {:ok, context}
      end
    end
  end
end
