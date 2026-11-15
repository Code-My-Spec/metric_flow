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
  this one exists for what a person watching the video sees -- and still
  asserts its own done-when at each stage, not just that elements exist.

  Deterministic and synthetic only: `MetricFlowTest.DashboardBuilderStub`
  scripts the agent's replies, and every metric below is seeded, never
  pulled from a real integration.

  Paced only while recording (`CMS_JOURNEY_VIDEO_DIR` set): a 1280x800
  viewport so the chat and canvas sit side by side the way a desktop user
  sees them, human-paced typing, and a ~3s hold after each visible step
  once that step's own assertions have already passed -- so the holds
  are purely for a watchable video and never substitute for a real wait.
  A plain `mix test --include e2e` run (no video dir set) adds none of
  this and runs at full speed.

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

  # Per-test override of the global browser_context_opts (config/test.exs) --
  # a strict superset of it (same conditional record_video, plus viewport)
  # rather than a parallel definition, so the two can't silently drift.
  # record_video's own `size` must be set explicitly to the viewport's size:
  # Playwright otherwise scales the recording down to fit an 800x800 box
  # (1280x800 -> 800x500), which is not the 1280x800 desktop layout asked for.
  @moduletag browser_context_opts:
               [viewport: %{width: 1280, height: 800}] ++
                 if(dir = System.get_env("CMS_JOURNEY_VIDEO_DIR"),
                   do: [record_video: %{dir: dir, size: %{width: 1280, height: 800}}],
                   else: []
                 )

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Dashboards
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope
  alias MetricFlowTest.DashboardBuilderStub
  alias MetricFlowTest.JourneyTestStage

  @initial_reply "I'll create a line chart showing impressions over time."
  @followup_reply "I've added clicks as a second chart alongside impressions."

  defp recording?, do: System.get_env("CMS_JOURNEY_VIDEO_DIR") not in [nil, ""]

  defp human_typing_delay, do: if(recording?(), do: 40, else: 0)

  # Only for a watchable video, and only placed after a step's own
  # assertions (or an action with nothing to wait for, like typing) have
  # already settled -- never a substitute for assert_has's own retrying.
  defp hold(conn, ms \\ 3_000) do
    if recording?(), do: Process.sleep(ms)
    conn
  end

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

    conn =
      conn
      |> visit("/users/log-in")
      |> type("form#login_form_password input[name='user[email]']", user.email,
        delay: human_typing_delay()
      )
      |> type("form#login_form_password input[name='user[password]']", "hello world!",
        delay: human_typing_delay()
      )
      |> click("form#login_form_password button")
      # Main's requirement (C): prove Dana actually landed signed in before
      # going anywhere -- UserAuth.signed_in_path/1 sends a fresh login to
      # /app/chat, the default authenticated home.
      |> assert_path("/app/chat")
      |> hold()
      |> visit("/app/dashboards/new")

    conn =
      JourneyTestStage.stage(conn, "Ask for a dashboard", fn conn ->
        Application.put_env(
          :metric_flow,
          :command_runner,
          DashboardBuilderStub.generate_initial_titled()
        )

        conn
        |> type(
          "[data-role='dashboard-chat-input']",
          "Show me a stat tile of total impressions and a line chart of impressions over time",
          delay: human_typing_delay()
        )
        |> hold()
        |> click("[data-role='dashboard-chat-send-btn']")
        |> assert_has("[data-role='dashboard-chat-message']", @initial_reply)
        # Done-when: the stat tile's own VALUE is the seeded total, not just
        # that a stat tile exists, and the chart card carries its own title.
        |> assert_has("[data-role='stat-tile-value']", "100")
        |> assert_has("[data-role='visualization-card']", "Impressions Over Time")
        |> hold()
      end)

    assert [dashboard] = Dashboards.list_dashboards(scope)

    # Done-when: the agent named the dashboard from the spec's own title,
    # not left it as the raw request text -- checked server-side (the
    # same thing criterion 1068 checks), not by scraping the name input's
    # DOM attribute.
    assert dashboard.name == "Impressions Overview"

    conn =
      JourneyTestStage.stage(conn, "Refine the dashboard", fn conn ->
        Application.put_env(
          :metric_flow,
          :command_runner,
          DashboardBuilderStub.generate_followup()
        )

        conn
        |> type(
          "[data-role='dashboard-chat-input']",
          "Add clicks as a second chart",
          delay: human_typing_delay()
        )
        |> hold()
        |> click("[data-role='dashboard-chat-send-btn']")
        |> assert_has("[data-role='dashboard-chat-message']", @followup_reply)
        # Done-when: the new card is the clicks chart, by its own title --
        # and the original stat and chart are still there, unchanged, which
        # is what "refined in place" means (one dashboard, not a second one
        # built alongside the first -- confirmed below via list_dashboards).
        |> assert_has("[data-role='visualization-card']", "Clicks Over Time")
        |> assert_has("[data-role='stat-tile-value']", "100")
        |> assert_has("[data-role='visualization-card']", "Impressions Over Time")
        |> assert_has("[data-role='visualization-card']", count: 3)
        |> assert_path("/app/dashboards/#{dashboard.id}/edit")
        |> hold()
      end)

    # Refining replaced the same dashboard's spec, not created a second one --
    # compare by id, not the whole pinned struct: a2ui_spec and updated_at
    # legitimately changed under the refine.
    assert [refined_dashboard] = Dashboards.list_dashboards(scope)
    assert refined_dashboard.id == dashboard.id

    JourneyTestStage.stage(conn, "Save and reopen", fn conn ->
      conn
      |> visit("/app/dashboards")
      |> assert_has("[data-dashboard-id='#{dashboard.id}']", dashboard.name)
      |> hold()
      |> visit("/app/dashboards/#{dashboard.id}")
      # Done-when: the view page shows all three widgets, the clicks chart
      # included -- not just that the page loaded.
      |> assert_has("[data-role='visualization-card']", "Total Impressions")
      |> assert_has("[data-role='visualization-card']", "Impressions Over Time")
      |> assert_has("[data-role='visualization-card']", "Clicks Over Time")
      |> assert_has("[data-role='visualization-card']", count: 3)
      |> hold()
      |> click("[data-role='edit-dashboard-#{dashboard.id}']")
      # Done-when: reopening the editor shows the FULL chat history -- both
      # the build and the refine reply, not only the most recent one.
      |> assert_has("[data-role='dashboard-chat-message']", @initial_reply)
      |> assert_has("[data-role='dashboard-chat-message']", @followup_reply)
      |> assert_has("[data-role='visualization-card']", count: 3)
      |> hold()
    end)
  end
end
