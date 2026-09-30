defmodule MetricFlowSpex.SyncPullsFromAllActiveIntegrationsForAllAccountsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  @moduledoc """
  Verifies the scheduled sync is system-wide, not scoped to a single account.
  """

  spex "Sync pulls new data from all active integrations for all accounts", criterion: 102 do
    scenario "the scheduled sync runs for every account with an active integration" do
      given_ :owner_with_integrations

      given_ "a second, unrelated account also has an active integration", context do
        other_email = "other#{System.unique_integer([:positive])}@example.com"
        other_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: other_email, password: other_password, account_name: "Other Account"}
        )
        |> render_submit()

        MetricFlowSpex.Fixtures.create_integration_for(other_email, :google_ads)

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        other_conn =
          login_view
          |> form("#login_form_password",
            user: %{email: other_email, password: other_password, remember_me: true}
          )
          |> submit_form(login_conn)
          |> recycle()

        {:ok, Map.put(context, :other_conn, other_conn)}
      end

      when_ "the scheduled daily sync fires", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the first account's sync history shows a new entry", context do
        assert has_element?(context.view, "[data-role='sync-history-entry']")
        {:ok, context}
      end

      then_ "the second, unrelated account's sync history also shows a new entry", context do
        {:ok, other_view, _html} = live(context.other_conn, "/app/integrations/sync-history")
        assert has_element?(other_view, "[data-role='sync-history-entry']")
        {:ok, context}
      end
    end
  end
end
