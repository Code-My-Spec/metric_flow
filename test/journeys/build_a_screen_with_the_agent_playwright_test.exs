defmodule MetricFlowWeb.Journeys.BuildAScreenWithTheAgentPlaywrightTest do
  @moduledoc """
  Playwright twin of `build_a_screen_with_the_agent_test.exs` (journey
  66a06609), for the demo recorder (CodeMySpec.Journeys.DemoWalk). ONE
  continuous walk through the journey's three stages -- "Ask for a
  dashboard", "Refine the dashboard", "Save and reopen" -- against a real
  Chromium over a real HTTP listener (CMS_E2E), so the recording shows
  what the LiveView test can't: the builder cockpit itself, the agent's
  chat messages rendered beside the live dashboard canvas on the same
  page. Every behavioral assertion already lives in the LiveView test;
  this one exists for what a person watching the video sees.

  Deterministic and synthetic only: `MetricFlowTest.DashboardBuilderStub`
  scripts the agent's replies, and every metric below is seeded, never
  pulled from a real integration.

  Excluded from a plain `mix test` (`test/test_helper.exs` excludes
  `:e2e`). The demo recorder's own invocation, with a free port and a
  writable video directory:

      MIX_ENV=test PHX_SERVER=1 CMS_E2E=1 CMS_E2E_PORT=4102 \\
        CMS_JOURNEY_VIDEO_DIR=/tmp/journey-video \\
        elixir -S mix test --include e2e \\
        test/journeys/build_a_screen_with_the_agent_playwright_test.exs
  """

  use PhoenixTest.Playwright.Case, async: false

  @moduletag :e2e

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Dashboards
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope
  alias MetricFlowTest.DashboardBuilderStub
  alias MetricFlowTest.JourneyTestStage

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

  test "Dana builds, refines, and reopens a dashboard by chatting with the agent", %{conn: conn} do
    user = user_fixture()
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
    insert_metric!(user, %{provider: :google_ads, metric_name: "clicks", value: 10.0})
    scope = Scope.for_user(user)

    conn
    |> visit("/users/log-in")
    |> type("form#login_form_password input[name='user[email]']", user.email)
    |> type("form#login_form_password input[name='user[password]']", "hello world!")
    |> click("form#login_form_password button")
    |> visit("/app/dashboards/new")
    |> JourneyTestStage.stage("Ask for a dashboard", fn conn ->
      Application.put_env(:metric_flow, :command_runner, DashboardBuilderStub.generate_initial())

      conn
      |> type(
        "[data-role='dashboard-chat-input']",
        "Show me a stat tile of total impressions and a line chart of impressions over time"
      )
      |> click("[data-role='dashboard-chat-send-btn']")
      |> assert_has(
        "[data-role='dashboard-chat-message']",
        "I'll create a line chart showing impressions over time."
      )
      |> assert_has("[data-role='dashboard-chat-panel']", [])
      |> assert_has("[data-role='visualization-card']", count: 2)
      |> assert_has("[data-role='echarts-chart']", [])
      |> assert_has("[data-role='stat-tile-value']", [])
    end)
    |> JourneyTestStage.stage("Refine the dashboard", fn conn ->
      Application.put_env(:metric_flow, :command_runner, DashboardBuilderStub.generate_followup())

      conn
      |> type("[data-role='dashboard-chat-input']", "Add clicks as a second chart")
      |> click("[data-role='dashboard-chat-send-btn']")
      |> assert_has(
        "[data-role='dashboard-chat-message']",
        "I've added clicks as a second chart alongside impressions."
      )
      |> assert_has("[data-role='dashboard-chat-panel']", [])
      |> assert_has("[data-role='visualization-card']", count: 3)
    end)
    |> JourneyTestStage.stage("Save and reopen", fn conn ->
      assert [dashboard] = Dashboards.list_dashboards(scope)

      conn
      |> visit("/app/dashboards")
      |> assert_has("[data-dashboard-id='#{dashboard.id}']", [])
      |> visit("/app/dashboards/#{dashboard.id}")
      |> assert_has("[data-role='echarts-chart']", [])
      |> assert_has("[data-role='edit-dashboard-#{dashboard.id}']", [])
      |> click("[data-role='edit-dashboard-#{dashboard.id}']")
      |> assert_has(
        "[data-role='dashboard-chat-message']",
        "I've added clicks as a second chart alongside impressions."
      )
      |> assert_has("[data-role='dashboard-chat-panel']", [])
      |> assert_has("[data-role='visualization-card']", count: 3)
    end)
  end
end
