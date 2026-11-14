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

  Multi-widget (455ea40): the backend can create more than one dashboard
  element from a single chat turn when the model calls `update_spec` more
  than once ("a single chat message naming two distinct widget types
  produces two widgets", below), and as of 455ea40 the dashboard editor's
  chat (`dashboard_live/editor.ex`'s `send_dashboard_chat` handler) passes
  `multi_widget: true` to `VizChat.send_message/3`, which adds explicit
  "call update_spec ONCE PER WIDGET" guidance to the system prompt. "The
  dashboard chat tells the model ..." below asserts on the real prompt
  this path sends, through the same LiveView event the live app uses, not
  a scripted response -- so it only passes once that guidance (or an
  equivalent add-widget tool) genuinely reaches the model on this path.
  The single-visualization editor (`MetricFlow.Ai.viz_chat/4`) does not
  pass `multi_widget: true` and is checked separately for the converse.
  See journey_result.md Journey 6 for the live walk at d4a75d8 that found
  the gap, including the model's own words and a screenshot; it will be
  re-walked at 455ea40 to confirm the live model actually produces two
  widgets now that the guidance is live.

  Missing-metric redirect, a named "Edit with agent" resume action, and
  versioning/restore are not asserted here; see journey_result.md
  Journey 6 for what was observed.
  """

  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Ai
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

  # The capturing command_runner below runs inside the chat handler's own
  # Task.async, off the test process -- poll the agent instead of a fixed
  # sleep, same reasoning as wait_for_chart/2.
  defp wait_for_capture(agent, deadline \\ System.monotonic_time(:millisecond) + 2000) do
    case Agent.get(agent, & &1) do
      nil ->
        if System.monotonic_time(:millisecond) >= deadline do
          nil
        else
          Process.sleep(20)
          wait_for_capture(agent, deadline)
        end

      args ->
        args
    end
  end

  defp capturing_runner(agent) do
    fn _exe, args, _opts ->
      Agent.update(agent, fn _ -> args end)

      envelope =
        Jason.encode!(%{
          "type" => "result",
          "is_error" => false,
          "structured_output" => %{"stop_reason" => "end_turn", "text" => "ok", "tool_calls" => []}
        })

      {envelope, 0}
    end
  end

  defp decode_prompt_payload(args) do
    args
    |> List.last()
    |> String.split("Transcript payload:\n", parts: 2)
    |> List.last()
    |> Jason.decode!()
  end

  defp multi_widget_guidance_present?(payload) do
    update_spec_tool = Enum.find(payload["available_tools"], &(&1["name"] == "update_spec"))

    other_tool_names =
      payload["available_tools"]
      |> Enum.map(& &1["name"])
      |> Enum.reject(&(&1 == "update_spec"))

    system_prompt_text = payload["system_prompt"] || ""
    update_spec_description = update_spec_tool["description"]
    combined_text = system_prompt_text <> "\n" <> update_spec_description

    has_dedicated_widget_tool =
      Enum.any?(other_tool_names, &String.contains?(String.downcase(&1), "widget"))

    mentions_multi_call =
      Regex.match?(
        ~r/update_spec.{0,160}(more than once|multiple times|once per widget|again for (a|another) widget|separate (dashboard )?element)/is,
        combined_text
      )

    has_dedicated_widget_tool or mentions_multi_call
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
      MetricFlowTest.VizChatStub.generate_initial()
    )

    render_submit(view, "send_dashboard_chat", %{
      "message" => "Add a headline stat of total clicks and a line chart of impressions over time"
    })

    html = wait_for_chart(view)

    Application.delete_env(:metric_flow, :command_runner)

    # Backend mechanism only: when the model calls update_spec twice in one
    # turn, add_visualization_from_chat_spec/2 creates two separate
    # dashboard elements rather than overwriting. This confirms that
    # mechanism exists; the test below confirms the model is actually told
    # it can use it on this path.
    cards = html |> Floki.parse_fragment!() |> Floki.find("[data-role='visualization-card']")
    assert length(cards) == 2
  end

  test "the dashboard chat tells the model it can call update_spec once per widget", %{
    conn: conn
  } do
    {:ok, agent} = Agent.start_link(fn -> nil end)

    user = user_fixture()
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
    insert_metric!(user, %{provider: :google_ads, metric_name: "clicks", value: 10.0})

    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

    Application.put_env(:metric_flow, :command_runner, capturing_runner(agent))

    render_submit(view, "send_dashboard_chat", %{
      "message" => "Add a stat tile and a line chart"
    })

    args = wait_for_capture(agent)

    Application.delete_env(:metric_flow, :command_runner)

    refute is_nil(args), "the dashboard chat never reached the command_runner"

    payload = decode_prompt_payload(args)

    # Story 74 rule 2: a multi-widget request should produce separate
    # dashboard elements. The backend mechanism exists (two update_spec
    # calls -> two elements, confirmed by the test above). This asserts on
    # the actual prompt/tool text the dashboard chat sends on this path --
    # via a capturing command_runner driven through the same LiveView event
    # the live app uses, not a scripted response -- so it only passes once
    # that guidance (or a dedicated add-widget tool) genuinely reaches the
    # model here.
    assert multi_widget_guidance_present?(payload)
  end

  test "the single-visualization editor's chat does not get the multi-widget guidance" do
    {:ok, agent} = Agent.start_link(fn -> nil end)

    user = user_fixture()
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
    scope = Scope.for_user(user)

    Ai.viz_chat(scope, nil, "Show me impressions over time", command_runner: capturing_runner(agent))

    args = Agent.get(agent, & &1)
    refute is_nil(args), "the visualization chat never reached the command_runner"

    payload = decode_prompt_payload(args)

    # Converse of the test above: the single-visualization editor builds
    # exactly one chart and never passes multi_widget: true, so neither
    # its system prompt nor the (shared) update_spec tool description it
    # receives should carry the "call update_spec again per widget"
    # guidance -- that's the dashboard chat's job alone. Checks both
    # sources via multi_widget_guidance_present?/1, the same helper the
    # test above uses, so a leak into either one is caught here.
    refute multi_widget_guidance_present?(payload)
  end

end
