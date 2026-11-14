defmodule MetricFlowWeb.Journeys.BuildAScreenWithTheAgentTest do
  @moduledoc """
  Journey 6 from `.code_my_spec/qa/journey_plan.md` (Story 74): a user
  describes a dashboard in chat and the agent builds it as a draft.

  Stage "Ask for a dashboard" (684d9a0): chat builds one visualization
  from natural language -- confirmed live in
  `.code_my_spec/qa/journey_result.md` Journey 6.

  Draft autosave (950932f): the agent's first build saves a draft
  dashboard with no explicit save, and reopening it shows the same
  dashboard -- confirmed live in journey_result.md Journey 6.

  Multi-widget (d4a75d8): the backend now supports creating more than one
  dashboard element from a single chat turn when the model calls
  `update_spec` more than once (see `VizChatStub.generate_initial/0`'s
  moduledoc) -- but the deployed model doesn't know to do that. Walked
  live (2026-11-14): asked for a stat tile and a line chart in one
  message, the model called `update_spec` once with both views combined
  into a single Vega-Lite `vconcat` spec, producing one card, not two. On
  an explicit follow-up asking for "two separate widgets ... not one
  combined chart," the model said it has no tool to create or manage
  separate dashboard elements, only `update_spec` for one spec. So Story
  74 rule 2 still isn't satisfied on the real surface -- the gap is now
  narrower than "the backend can't do it" (it can) to "the model isn't
  told it can call the tool again instead of overwriting." This test
  uses `VizChatStub.generate_multi_widget_combined/0`, which reproduces
  that observed single-combined-spec response, so the assertion below
  documents the real gap rather than the backend-only mechanism
  `generate_initial/0` exercises.

  Missing-metric redirect, a named "Edit with agent" resume action, and
  versioning/restore are not asserted here; see journey_result.md
  Journey 6 for what was observed.
  """

  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Dashboards
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

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

  defp build_chart_via_chat(view) do
    Application.put_env(
      :metric_flow,
      :command_runner,
      MetricFlowTest.VizChatStub.generate_initial()
    )

    render_submit(view, "send_dashboard_chat", %{
      "message" => "Show me impressions over time as a line chart"
    })

    html = wait_for_chart(view)

    Application.delete_env(:metric_flow, :command_runner)

    html
  end

  # The chat handler resolves via a plain `Task.async` + `handle_info`, not
  # LiveView's `assign_async`/`start_async`, so `render_async/1` can't track
  # it -- poll instead of a fixed sleep so this doesn't flake under load.
  defp wait_for_chart(view, deadline \\ System.monotonic_time(:millisecond) + 2000) do
    html = render(view)

    cond do
      has_element?(view, "[data-role='vega-lite-chart']") -> html
      System.monotonic_time(:millisecond) >= deadline -> html
      true ->
        Process.sleep(20)
        wait_for_chart(view, deadline)
    end
  end

  test "describing a dashboard in chat builds a visualization onto the canvas", %{conn: conn} do
    user = user_fixture()
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

    conn = log_in_user(conn, user)

    # Step 2: a chat affordance to describe the dashboard in natural language
    {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
    assert has_element?(view, "[data-role='dashboard-chat-input']")

    # Step 3: the agent builds what was described, using real metric data
    html = build_chart_via_chat(view)

    assert html =~ "create a line chart showing impressions over time."
    assert has_element?(view, "[data-role='vega-lite-chart']")
  end

  test "the agent's first build is saved as a draft, so a reload shows the same dashboard", %{
    conn: conn
  } do
    user = user_fixture()
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
    scope = Scope.for_user(user)

    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
    build_chart_via_chat(view)

    # Story 74, rule 1: "A dashboard is saved as a draft the first time the
    # agent builds something, with no explicit save needed."
    assert [dashboard] = Dashboards.list_dashboards(scope)

    # Story 74, scenario: "refreshing the page shows the same dashboard"
    {:ok, _reopened_view, reopened_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

    assert reopened_html =~ "Show me impressions over time as a line chart"
    assert reopened_html =~ ~s(data-role="vega-lite-chart")
  end

  test "a single chat message naming two distinct widget types produces two widgets", %{
    conn: conn
  } do
    user = user_fixture()
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
    insert_metric!(user, %{provider: :google_ads, metric_name: "clicks", value: 10.0})

    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

    Application.put_env(
      :metric_flow,
      :command_runner,
      MetricFlowTest.VizChatStub.generate_multi_widget_combined()
    )

    render_submit(view, "send_dashboard_chat", %{
      "message" => "Add a headline stat of total clicks and a line chart of impressions over time"
    })

    html = wait_for_chart(view)

    Application.delete_env(:metric_flow, :command_runner)

    # Story 74, rule 2: "The agent can build charts ..., stat tiles,
    # tables, headings, text, layout containers and interactive controls
    # on a dashboard", scenario: "the dashboard shows a stat tile, a line
    # chart and a table in a layout" from one request. Still fails live
    # (2026-11-14): the model combines both views into one Vega-Lite
    # `vconcat` spec rather than calling `update_spec` once per widget, so
    # the canvas gets one card, not two.
    cards = html |> Floki.parse_fragment!() |> Floki.find("[data-role='visualization-card']")
        assert length(cards) == 2
  end
end
