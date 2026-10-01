defmodule MetricFlowWeb.Journeys.IntegrationDashboardAndDataSyncTest do
  @moduledoc """
  Journey 3 from `.code_my_spec/qa/journey_plan.md`: an owner with a
  connected integration sees it on the integrations and sync history pages,
  and the dashboard renders real chart data instead of the onboarding prompt.
  """

  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Repo

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs \\ %{}) do
    defaults = %{
      name: "QA Test Account",
      slug: unique_slug(),
      type: "client",
      originator_user_id: user.id
    }

    %Account{}
    |> Account.creation_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_member!(account, user, role) do
    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert!()
  end

  defp canned_dashboard_fixture(user, attrs \\ %{}) do
    defaults = %{name: "Marketing Overview", user_id: user.id, built_in: true}

    %Dashboard{}
    |> Dashboard.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  test "shows connected integration with sync status and renders a dashboard with real data", %{conn: conn} do
    user = user_fixture()
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    integration = integration_fixture(user, %{provider: :google_ads})
    insert_metric!(user, %{provider: :google_ads, metric_name: "clicks", value: 42.0})

    conn = log_in_user(conn, user)

    # Step 2-3: OAuth provider cards show Connected for google_ads
    {:ok, _lv, connect_html} = live(conn, ~p"/app/integrations/connect")
    assert connect_html =~ "Connected"

    # Step 4-7: platform list shows the connected integration and a Sync Now control
    {:ok, _lv, integrations_html} = live(conn, ~p"/app/integrations")
    assert integrations_html =~ "Google Ads"
    assert integrations_html =~ "Sync Now"

    # Step 8-9: sync history page renders
    {:ok, _lv, history_html} = live(conn, ~p"/app/integrations/sync-history")
    assert history_html =~ "Sync History"

    # Step 10-14: dashboard with real data, not the onboarding empty state
    dashboard = canned_dashboard_fixture(user)
    {:ok, _lv, dashboard_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

    refute dashboard_html =~ ~s(data-role="onboarding-prompt")
    assert dashboard_html =~ ~s(data-role="vega-lite-chart")

    assert integration.provider == :google_ads
  end
end
