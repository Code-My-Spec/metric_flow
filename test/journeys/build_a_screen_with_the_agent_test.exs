defmodule MetricFlowWeb.Journeys.BuildAScreenWithTheAgentTest do
  @moduledoc """
  Journey 6 from `.code_my_spec/qa/journey_plan.md` (Story 74): a user
  describes a dashboard in chat and the agent builds it as a draft.

  Stage "Ask for a dashboard" (684d9a0): chat builds one visualization
  from natural language -- confirmed live in
  `.code_my_spec/qa/journey_result.md` Journey 6. Remaining stages (draft
  autosave, multi-widget composition, missing-metric redirect, agent-chat
  history, versioning/restore) are not built yet and are not asserted
  here; see that same section for what was observed.
  """

  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
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
    Application.put_env(
      :metric_flow,
      :command_runner,
      MetricFlowTest.VizChatStub.generate_initial()
    )

    render_submit(view, "send_dashboard_chat", %{
      "message" => "Show me impressions over time as a line chart"
    })

    Process.sleep(100)
    html = render(view)

    Application.delete_env(:metric_flow, :command_runner)

    assert html =~ "I'll create a line chart showing impressions over time."
    assert has_element?(view, "[data-role='vega-lite-chart']")

    # Steps 4-5 (not built yet -- see journey_result.md Journey 6):
    # reloading loses the chat and chart since there is no draft autosave,
    # and there is no mixed stat-tile/chart/table response, missing-metric
    # redirect to Integrations, "Edit with agent" history, or
    # versioning/restore.
  end
end
