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

  Stages wrapped below (CodeMySpec journey 66a06609's own three named
  stages, per `list_customer_workflows`, not paraphrased): "Ask for a
  dashboard", "Refine the dashboard" (story 74), "Save and reopen"
  (story 75). No `stage/2`/`JourneyTestStage` helper existed anywhere in
  this project or its deps to mirror, so `stage/2` below is a minimal
  local one: it runs the given function and returns its result,
  existing only so the harness's source-level stage detection can find
  the exact stage names each test exercises.
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

  defp stage(_name, fun), do: fun.()

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
      MetricFlowTest.DashboardBuilderStub.generate_initial()
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
      has_element?(view, "[data-role='echarts-chart']") -> html
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

  defp wait_for(fun, deadline \\ System.monotonic_time(:millisecond) + 2000) do
    case fun.() do
      nil ->
        if System.monotonic_time(:millisecond) >= deadline do
          nil
        else
          Process.sleep(20)
          wait_for(fun, deadline)
        end

      result ->
        result
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

  # Queries paper_trail's own versions table directly rather than
  # Dashboards.list_dashboard_versions/1 -- main's review (10fd033,
  # 2026-11-14) has the coder removing that hand-rolled DashboardVersion
  # table/repo function entirely in favor of paper_trail.
  defp paper_trail_version_count(dashboard_id) do
    %{rows: [[count]]} =
      Repo.query!(
        "select count(*) from versions where item_type = 'Dashboard' and item_id = $1",
        [dashboard_id]
      )

    count
  end

  defp stat_tile_total(html) do
    text =
      html
      |> Floki.parse_fragment!()
      |> Floki.find("[data-role='stat-tile-value']")
      |> Floki.text()
      |> String.trim()
      |> String.replace(",", "")

    {value, _} = Float.parse(text)
    value
  end

  defp decode_prompt_payload(args) do
    args
    |> List.last()
    |> String.split("Transcript payload:\n", parts: 2)
    |> List.last()
    |> Jason.decode!()
  end

  # Story 74 rule 2 / main's call (2026-11-14): under set_dashboard_spec
  # there's no "call it again per widget" mechanism to tell the model
  # about -- there's one tool and one call. What has to be said instead
  # is the one-call equivalent: a request for several widgets means
  # several components in that one complete spec. Live testing (pre-A2UI,
  # same gap under VizChat) showed the model doesn't do this reliably
  # without being told explicitly, so this reads the real DashboardBuilder
  # payload (not a scripted response) and requires both halves to be
  # spelled out somewhere in the system prompt or set_dashboard_spec's own
  # description: that multiple widgets are possible, and that they belong
  # in one call/spec together.
  defp multi_widget_guidance_present?(payload) do
    set_dashboard_spec_tool =
      Enum.find(payload["available_tools"] || [], &(&1["name"] == "set_dashboard_spec"))

    system_prompt_text = payload["system_prompt"] || ""
    tool_description = (set_dashboard_spec_tool && set_dashboard_spec_tool["description"]) || ""
    combined_text = system_prompt_text <> "\n" <> tool_description

    mentions_several_widgets =
      Regex.match?(
        ~r/(multiple|several|more than one|two or more)\s+(widgets|components)/i,
        combined_text
      )

    mentions_one_call =
      Regex.match?(
        ~r/(one|a single|the same)\s+(call|set_dashboard_spec call|spec)/i,
        combined_text
      )

    mentions_several_widgets and mentions_one_call
  end

  test "describing a dashboard in chat builds a visualization onto the canvas", %{conn: conn} do
    stage("Ask for a dashboard", fn ->
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
      assert has_element?(view, "[data-role='echarts-chart']")
    end)
  end

  test "the agent's first build navigates to the draft's own page, so a reload keeps it", %{
    conn: conn
  } do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      # Story 74, scenario: "refreshing the page shows the same dashboard".
      # That requires the LiveView to actually navigate off /new to the
      # draft's own URL once it exists -- a plain reload of /new itself
      # can't restore anything, since mount/3 for :new always starts blank.
      # Confirmed live by main (2026-11-14, de23c19): the draft dashboard
      # record is created, but the URL stays on /app/dashboards/new and
      # reloading it shows an empty canvas (0 cards, 0 chat messages). The
      # existing test below (reopening via a direct /edit visit) still
      # passes and is not evidence this works, since it never exercises
      # /new's own reload path -- see journey_result.md Journey 6.
      assert_patch(view, ~p"/app/dashboards/#{dashboard.id}/edit", 2_000)
    end)
  end

  test "a chat-built stat tile keeps its own visualization type after reopening", %{
    conn: conn
  } do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.generate_initial()
      )

      render_submit(view, "send_dashboard_chat", %{
        "message" => "Add a stat tile and a line chart"
      })

      wait_for_chart(view)

      Application.delete_env(:metric_flow, :command_runner)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      # Fresh mount, not the same `view` -- this is what actually exercises
      # load_visualizations_from_dashboard/1's reload path, the same one a
      # real browser reload hits.
      {:ok, _edit_view, edit_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      # Story 74 rule 2: a stat tile stays a stat tile, not silently
      # reclassified as a line chart. Confirmed live by main (2026-11-14,
      # a8e2d7b): after reopening /edit, both cards' badges read "line",
      # including the one built as a text mark ("Total Impressions"). Root
      # cause: load_visualizations_from_dashboard/1 in dashboard_live/
      # editor.ex derives chart_type via `Map.get(vega_spec, "chart_type")
      # || "line"`, which only understands the stub
      # %{"metric_name" => _, "chart_type" => _} shape, not a real
      # chat-generated spec's "mark" key -- it should fall back to
      # extract_chart_type_from_spec/1 (already defined in the same module)
      # instead of hardcoding "line".
      stat_tile_card =
        edit_html
        |> Floki.parse_fragment!()
        |> Floki.find("[data-role='visualization-card']")
        |> Enum.find(fn card -> Floki.text(card) =~ "Total Impressions" end)

      refute is_nil(stat_tile_card), "expected a 'Total Impressions' card after reopening"

      badge_text =
        stat_tile_card
        |> Floki.find(".badge")
        |> Floki.text()
        |> String.trim()

      assert badge_text == "text"
    end)
  end

  test "the agent's first build is saved as a draft, so a reload shows the same dashboard", %{
    conn: conn
  } do
    stage("Save and reopen", fn ->
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
      assert reopened_html =~ ~s(data-role="echarts-chart")
    end)
  end

  test "a single chat message naming two distinct widget types produces two widgets", %{
    conn: conn
  } do
    stage("Ask for a dashboard", fn ->
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
        MetricFlowTest.DashboardBuilderStub.generate_initial()
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
    end)
  end

  test "the dashboard chat tells the model that several widgets go in one complete spec", %{
    conn: conn
  } do
    stage("Ask for a dashboard", fn ->
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
      # dashboard elements. The backend mechanism exists (one
      # set_dashboard_spec call carrying several components -> several
      # elements, confirmed by the DashboardBuilderStub-backed test above).
      # This asserts on the actual prompt/tool text the dashboard chat sends
      # on this path -- via a capturing command_runner driven through the
      # same LiveView event the live app uses, not a scripted response -- so
      # it only passes once the model is explicitly told that several
      # widgets means several components in that one call, matching the
      # same gap found under VizChat before the A2UI rebuild (main,
      # 2026-11-14): the model doesn't reach for that mechanism reliably
      # without being told.
      assert multi_widget_guidance_present?(payload)
    end)
  end

  test "the single-visualization editor's chat does not get the multi-widget guidance" do
    stage("Ask for a dashboard", fn ->
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
    end)
  end

  test "refining an already-saved dashboard through chat records a restorable version", %{
    conn: conn
  } do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      insert_metric!(user, %{provider: :google_ads, metric_name: "clicks", value: 10.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      # Story 74, scenario (journey_plan.md Journey 6 step 4): reopen an
      # already-saved dashboard and let the agent keep refining it.
      {:ok, edit_view, _edit_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.generate_followup()
      )

      render_submit(edit_view, "send_dashboard_chat", %{
        "message" => "Add clicks as a second series"
      })

      wait_for_chart(edit_view)

      Application.delete_env(:metric_flow, :command_runner)

      # Story 74, scenario (journey_plan.md Journey 6 step 5): each agent
      # change is recorded as a version, with the ability to restore an
      # earlier one. No version schema or UI exists yet (confirmed: the
      # Dashboard schema has no version association, and there is no
      # DashboardVersion module anywhere in lib/), so this fails cleanly
      # rather than crashing -- the coder's next work item for this journey.
      assert has_element?(edit_view, "[data-role='dashboard-version-list']")
    end)
  end

  test "an earlier version can be restored", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      insert_metric!(user, %{provider: :google_ads, metric_name: "clicks", value: 10.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, edit_view, _edit_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.generate_followup()
      )

      render_submit(edit_view, "send_dashboard_chat", %{
        "message" => "Add clicks as a second series"
      })

      wait_for_chart(edit_view)

      Application.delete_env(:metric_flow, :command_runner)

      # Story 74, rule 7: "... with the ability to restore an earlier
      # version." Fixed at 58026f9: each version entry has a Restore
      # button (restore_version event).
      assert has_element?(edit_view, "[data-role='restore-version']")
    end)
  end

  test "when no metrics exist, the agent's reply includes a link to connect a platform", %{
    conn: conn
  } do
    stage("Ask for a dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      # Deliberately no insert_metric! -- this user has no synced metrics.

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      html =
        render_submit(view, "send_dashboard_chat", %{"message" => "Show me a traffic dashboard"})

      assert html =~ "No metrics are available yet"

      # Story 74, rule 3: "... offers a link to connect a platform." Scope
      # to the chat message itself, not the whole page -- the sidebar nav
      # already links to /app/integrations regardless of the chat reply,
      # which would make an unscoped `html =~ ~s(href="/app/integrations")`
      # pass even though the reply has no link at all. The chat bubble
      # renders message content as plain escaped text
      # (`<p class="whitespace-pre-wrap">{msg.content}</p>` in
      # dashboard_live/editor.ex), so mentioning Integrations in prose
      # isn't an actual link.
      chat_message_links =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("[data-role='dashboard-chat-message'] a[href='/app/integrations']")

      assert chat_message_links != []
    end)
  end

  test "a saved dashboard has an \"Edit with agent\" entry point, not just a generic Edit link",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [_dashboard] = Dashboards.list_dashboards(scope)

      {:ok, _index_view, index_html} = live(conn, ~p"/app/dashboards")

      # Story 74, rule 4: "... choosing Edit with agent restores the
      # conversation and the agent continues from the current dashboard."
      # The dashboards index only offers a generic "Edit" link
      # (data-role="edit-dashboard-:id" in dashboard_live/index.ex), not
      # one labeled "Edit with agent". Visiting that link does restore the
      # chat history (confirmed since 950932f), so the substance already
      # works -- there's just no distinctly-labeled entry point for it.
      assert index_html =~ "Edit with agent"
    end)
  end

  test "chat on a reopened dashboard is told about its existing widgets", %{conn: conn} do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, agent} = Agent.start_link(fn -> nil end)

      # Fresh mount -- the same path "Edit with agent" takes.
      {:ok, edit_view, _edit_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      Application.put_env(:metric_flow, :command_runner, capturing_runner(agent))

      render_submit(edit_view, "send_dashboard_chat", %{"message" => "Make the line thicker"})

      args = wait_for_capture(agent)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(args), "the dashboard chat never reached the command_runner"

      payload = decode_prompt_payload(args)

      # Story 74 rule 4 / criterion 1062: "Edit with agent restores the
      # conversation and the agent continues from the current dashboard."
      # Confirmed live by main (2026-11-14, 58026f9): asked to refine a
      # reopened dashboard, the real model replied "I also don't see a
      # line chart or stat tile in this conversation, so there's nothing
      # for me to edit." Root cause: dashboard_chat_context resets to nil
      # on every /edit mount, and current_spec is never passed to
      # VizChat.send_message on the dashboard chat path, so a message sent
      # right after reopening carries no record of existing widgets at
      # all. No Story 74 rule covers removing widgets through chat, so
      # this only checks the widget is mentioned, not that the model is
      # told it may delete anything.
      full_payload_text = Jason.encode!(payload)
      assert full_payload_text =~ "Impressions Over Time"
    end)
  end

  test "an interactive filter control re-queries metrics without writing anywhere", %{
    conn: conn
  } do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      # Story 74 rule 5 / criterion 1063: "Interactive controls on a
      # dashboard only re-run metric queries and change what is shown;
      # they never write anywhere or call other tools." No concept of an
      # interactive control dashboard element exists anywhere in
      # dashboard_live/editor.ex -- update_spec only ever produces
      # Vega-Lite visualization specs, so there's nothing to pick a value
      # in and nothing that would re-query metrics on change.
      assert has_element?(view, "[data-role='filter-control']")
    end)
  end

  test "a model error leaves the dashboard unchanged and lets the user retry", %{conn: conn} do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      cards_before =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("[data-role='visualization-card']")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.ClaudeCodeStub.error("model unavailable")
      )

      render_submit(view, "send_dashboard_chat", %{"message" => "Add a bar chart of clicks"})

      html =
        wait_for(fn ->
          rendered = render(view)
          if rendered =~ "Error", do: rendered, else: nil
        end)

      Application.delete_env(:metric_flow, :command_runner)

      # Story 74 rule 6 / criterion 1064: "Dana sees a clear error in the
      # chat and the dashboard stays exactly as it was ... and she can
      # retry the request."
      assert html =~ "Error"

      cards_after =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("[data-role='visualization-card']")

      assert cards_after == cards_before
      refute has_element?(view, "[data-role='dashboard-chat-send-btn'][disabled]")
    end)
  end

  test "a dashboard's filter values persist across a reopen", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, edit_view, _edit_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      # Story 74 criteria 1063/1066: confirmed live by main (2026-11-14,
      # 5ee7d7c on dashboard 11): choosing "Last 90 days" in a real
      # browser fired zero filter_date_range events and no UPDATE
      # dashboards -- the select isn't wrapped in a <form>, so there's
      # nothing for the browser to submit the change through. Assert the
      # structural fix before driving the change, and scope to
      # [data-role='filter-control'] rather than a bare "form[phx-change]"
      # -- the dashboard-name form above it also carries phx-change
      # (phx-change="validate_name"), so an unscoped selector would match
      # two forms once this one exists.
      assert has_element?(edit_view, "[data-role='filter-control'] form[phx-change] select")

      edit_view
      |> element("[data-role='filter-control'] form[phx-change]")
      |> render_change(%{"range" => "90"})

      # Fresh mount -- the same thing a real reload or reopen does. The
      # filter_date_range handler only does `assign(socket,
      # :dashboard_date_range, range)`, and every mount (:new and :edit)
      # hardcodes :dashboard_date_range back to "30" -- nothing persists
      # the choice to the Dashboard record, so a fresh mount always shows
      # 30 regardless of what was picked before.
      {:ok, _reopened_view, reopened_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      # Story 74 rule 8 / criterion 1066: a filter control's value is
      # "saved with the dashboard" and still shows on reopen.
      assert reopened_html =~ ~s(value="90" selected)
    end)
  end

  test "the model's next complete spec, naming the same component id, updates that widget in place",
       %{conn: conn} do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      cards_before =
        view |> render() |> Floki.parse_fragment!() |> Floki.find("[data-role='visualization-card']")

      assert length(cards_before) == 2

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.refine_to_area_chart()
      )

      render_submit(view, "send_dashboard_chat", %{
        "message" => "Change Impressions Over Time from a line chart to an area chart"
      })

      # wait_for_chart/1 only polls for *any* existing chart element, which
      # is already true from the first build -- it would return
      # immediately without actually waiting for this refine's async
      # result. Wait for the stub's own reply text instead.
      html =
        wait_for(fn ->
          rendered = render(view)
          if rendered =~ "changed it to an area chart", do: rendered, else: nil
        end)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(html), "the refine chat turn never completed"

      cards_after =
        html |> Floki.parse_fragment!() |> Floki.find("[data-role='visualization-card']")

      # Story 74 rules 2/4 (refining an existing widget): under
      # set_dashboard_spec there's no per-widget merge step left to break
      # (apply_a2ui_spec/2 replaces the whole canvas from whatever
      # components the model's latest call names) -- so the thing that
      # actually has to hold is that the model's next complete spec names
      # the SAME component id for the widget it's changing, rather than a
      # new one. Check both: the user-facing canvas still shows exactly
      # one "Impressions Over Time"/area card (not a duplicate), and the
      # stored a2ui_spec's "widget-1" component -- the chart's original id
      # -- is the one that now carries chartType "area".
      assert length(cards_after) == 2

      impressions_card = Enum.find(cards_after, &(Floki.text(&1) =~ "Impressions Over Time"))
      refute is_nil(impressions_card), "expected an 'Impressions Over Time' card to remain"

      badge_text = impressions_card |> Floki.find(".badge") |> Floki.text() |> String.trim()
      assert badge_text == "area"

      assert [dashboard] = Dashboards.list_dashboards(scope)
      components = dashboard.a2ui_spec["components"] || []

      chart_widget = Enum.find(components, &(&1["id"] == "widget-1"))
      refute is_nil(chart_widget), "expected component id widget-1 to still be present"
      assert chart_widget["chartType"] == "area"
    end)
  end

  test "the model's next complete spec updates the same component id in place even when it rewords the title",
       %{conn: conn} do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      cards_before =
        view |> render() |> Floki.parse_fragment!() |> Floki.find("[data-role='visualization-card']")

      assert length(cards_before) == 2

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.refine_to_area_chart_with_reworded_title()
      )

      render_submit(view, "send_dashboard_chat", %{
        "message" => "Change Impressions Over Time from a line chart to an area chart"
      })

      html =
        wait_for(fn ->
          rendered = render(view)
          if rendered =~ "changed it to an area chart", do: rendered, else: nil
        end)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(html), "the refine chat turn never completed"

      cards_after =
        html |> Floki.parse_fragment!() |> Floki.find("[data-role='visualization-card']")

      # Story 74 rules 2/4, criterion 1062: there's no title-matching merge
      # step left to fool by renaming a widget -- set_dashboard_spec always
      # replaces the whole canvas from the model's latest components list.
      # What has to hold is that the model's next complete spec keeps the
      # SAME component id for the widget it's renaming, so it's still
      # recognizable as the same widget rather than a duplicate under a
      # new name. Checked both ways: the canvas still shows exactly one
      # renamed card (not a second, orphaned "Impressions Over Time" one),
      # and the stored a2ui_spec's "widget-1" component -- the chart's
      # original id -- is the one now carrying the new title and chartType.
      assert length(cards_after) == 2

      reworded_card = Enum.find(cards_after, &(Floki.text(&1) =~ "Daily Impressions"))
      refute is_nil(reworded_card), "expected a 'Daily Impressions' card after the rename"

      badge_text = reworded_card |> Floki.find(".badge") |> Floki.text() |> String.trim()
      assert badge_text == "area"

      assert [dashboard] = Dashboards.list_dashboards(scope)
      components = dashboard.a2ui_spec["components"] || []

      chart_widget = Enum.find(components, &(&1["id"] == "widget-1"))
      refute is_nil(chart_widget), "expected component id widget-1 to still be present"
      assert chart_widget["title"] == "Daily Impressions"
      assert chart_widget["chartType"] == "area"
    end)
  end

  test "the existing widget's own component id is visible to the model, and the tool's contract makes it the key to update in place",
       %{conn: conn} do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      {:ok, agent} = Agent.start_link(fn -> nil end)

      Application.put_env(:metric_flow, :command_runner, capturing_runner(agent))

      render_submit(view, "send_dashboard_chat", %{"message" => "Make the line thicker"})

      args = wait_for_capture(agent)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(args), "the dashboard chat never reached the command_runner"

      payload = decode_prompt_payload(args)

      # Story 74 rules 2/4, criterion 1062: set_dashboard_spec has no
      # separate widget_id mechanism -- there's no per-widget edit tool at
      # all, only one tool that always takes the complete spec. What has
      # to hold instead (main, 2026-11-14): the model is shown the
      # dashboard's current spec, with each existing widget's own
      # component id (assigned at build time -- "widget-1" for the line
      # chart built by DashboardBuilderStub.generate_initial/0) still in
      # it, and the tool's own description states the full-replace
      # contract -- so reusing that id in the next call is how a widget
      # stays "the same widget" rather than becoming a new one.
      system_prompt_text = payload["system_prompt"] || ""

      assert system_prompt_text =~ "widget-1",
             "expected the existing chart widget's own component id to appear in the current spec shown to the model"

      set_dashboard_spec_tool =
        Enum.find(payload["available_tools"], &(&1["name"] == "set_dashboard_spec"))

      refute is_nil(set_dashboard_spec_tool), "expected set_dashboard_spec to be offered"

      description = set_dashboard_spec_tool["description"] || ""

      assert Regex.match?(~r/complete.{0,30}spec every time|no separate edit tool/i, description),
             "expected set_dashboard_spec's description to state the full-replace contract"
    end)
  end

  test "the agent is told to default to the last 30 days when no range is named", %{
    conn: conn
  } do
    stage("Ask for a dashboard", fn ->
      {:ok, agent} = Agent.start_link(fn -> nil end)

      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      Application.put_env(:metric_flow, :command_runner, capturing_runner(agent))

      render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions over time"})

      args = wait_for_capture(agent)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(args), "the dashboard chat never reached the command_runner"

      payload = decode_prompt_payload(args)

      # Story 74 rule 9 / criterion 1067: "When Dana does not name a date
      # range, the agent uses the last 30 days ending yesterday." Nothing
      # in VizChat's system prompt or tool descriptions mentions any
      # default date range at all (confirmed: no match for "date range",
      # "30 day" or "90 day" anywhere in viz_chat.ex or viz_tools/*.ex),
      # so a request with no range named has no documented default to
      # fall back to.
      combined_text =
        (payload["system_prompt"] || "") <>
          Enum.map_join(payload["available_tools"], "", &(&1["description"] || ""))

      assert Regex.match?(~r/last 30 days|30-day|30 day/i, combined_text)
    end)
  end

  test "a chat-built dashboard renders without any Vega-Lite remnants", %{conn: conn} do
    stage("Ask for a dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      html = build_chart_via_chat(view)

      # Story 74's notes (get_story 74): "Charts are ECharts" -- replacing
      # the Vega-Lite rendering path this dashboard builder uses today.
      # Only the negative half (no Vega-Lite rendering remnant survives a
      # chat build); the positive half (an ECharts container appears) is
      # its own test below, now that main settled the markup convention
      # ([data-role='echarts-chart'] with phx-hook="ECharts").
      refute html =~ "vega-embed"
      refute has_element?(view, "[data-role='vega-lite-chart']")
    end)
  end

  test "the dashboard editor has no hand-edit spec affordance", %{conn: conn} do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      # Story 74's notes (get_story 74): "Chat only: no hand-edit spec
      # editor." The dashboard editor currently has an "Edit Spec"
      # affordance (dashboard_live/editor.ex,
      # data-role="open-spec-panel", aria-label "Edit spec") that opens a
      # raw-spec text editor -- the opposite of chat-only authoring.
      refute has_element?(view, "[data-role='open-spec-panel']")
    end)
  end

  test "a chat build leaves the dashboard's a2ui_spec non-empty with at least one component", %{
    conn: conn
  } do
    stage("Ask for a dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      # Story 74's notes (get_story 74), field named by main: the builder
      # agent's one write tool sets dashboard.a2ui_spec, an A2UI surface
      # map with a "components" list. No such field exists on the
      # Dashboard schema yet (confirmed: lib/metric_flow/dashboards/
      # dashboard.ex has no a2ui_spec), and today's build path writes
      # Vega-Lite Visualization rows instead. Map.get returns nil for a
      # field the struct doesn't define rather than raising, so this
      # fails as a clear assertion, not a crash.
      a2ui_spec = Map.get(dashboard, :a2ui_spec)
      refute is_nil(a2ui_spec), "expected dashboard.a2ui_spec to be set after a chat build"

      components = a2ui_spec["components"] || []
      assert components != []
    end)
  end

  test "a2ui_spec components bind to metrics via query, not inline data", %{conn: conn} do
    stage("Ask for a dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      # Story 74's notes: "data is fetched at render time, never pasted
      # into the spec" -- each chart/stat component should carry a
      # "query" map (at least a "metric" key) and no inline "values"/
      # "data" rows. Fails at the same early guard as the test above,
      # since a2ui_spec doesn't exist yet; kept as its own test per this
      # file's one-test-per-criterion convention.
      a2ui_spec = Map.get(dashboard, :a2ui_spec)
      refute is_nil(a2ui_spec), "expected dashboard.a2ui_spec to be set after a chat build"

      components = a2ui_spec["components"] || []
      chart_or_stat_components = Enum.filter(components, &(&1["type"] in ["chart", "stat"]))

      assert chart_or_stat_components != []

      for component <- chart_or_stat_components do
        query = component["query"]
        refute is_nil(query), "expected component #{inspect(component["id"])} to carry a query"
        assert Map.has_key?(query, "metric")
        refute Map.has_key?(component, "values")
        refute Map.has_key?(component, "data")
      end
    end)
  end

  test "the dashboard chat offers set_dashboard_spec and query_metrics, not update_spec", %{
    conn: conn
  } do
    stage("Ask for a dashboard", fn ->
      {:ok, agent} = Agent.start_link(fn -> nil end)

      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      Application.put_env(:metric_flow, :command_runner, capturing_runner(agent))

      render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions over time"})

      args = wait_for_capture(agent)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(args), "the dashboard chat never reached the command_runner"

      payload = decode_prompt_payload(args)
      tool_names = Enum.map(payload["available_tools"], & &1["name"])

      # Story 74's notes (get_story 74): "a new builder-only agent
      # replaces MetricFlow.Ai.VizChat and has one write tool that sets
      # the A2UI blob (spec) on the dashboard record" -- named
      # set_dashboard_spec per main's naming decision -- "reusing the
      # QueryMetrics tool" (read-only, named query_metrics). Today the
      # dashboard chat still sends update_spec (VizChat's Vega-Lite
      # tool), never set_dashboard_spec or query_metrics.
      assert "set_dashboard_spec" in tool_names
      assert "query_metrics" in tool_names
      refute "update_spec" in tool_names
    end)
  end

  test "a chat build renders an ECharts container", %{conn: conn} do
    stage("Ask for a dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      # Story 74's notes: "Charts are ECharts." Per main's naming
      # decision: a [data-role='echarts-chart'] element with
      # phx-hook="ECharts". No such hook exists anywhere in assets/js or
      # lib/ yet (confirmed via grep), so this element can't be present.
      assert has_element?(view, "[data-role='echarts-chart'][phx-hook='ECharts']")
    end)
  end

  test "the listed versions are exactly the paper_trail versions, by count and order, and a restore adds exactly one",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      insert_metric!(user, %{provider: :google_ads, metric_name: "clicks", value: 10.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, edit_view, _edit_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.generate_followup()
      )

      render_submit(edit_view, "send_dashboard_chat", %{
        "message" => "Add clicks as a second chart"
      })

      # wait_for_chart/1 only polls for *any* existing chart element,
      # already true from the first build -- it would return
      # immediately without waiting for this refine's async result.
      # Wait for the stub's own reply text instead (same fix applied
      # elsewhere in this file for the same reason).
      refute is_nil(
               wait_for(fn ->
                 rendered = render(edit_view)
                 if rendered =~ "added clicks as a second chart", do: rendered, else: nil
               end)
             ),
             "the refine chat turn never completed"

      Application.delete_env(:metric_flow, :command_runner)

      before_restore_count = paper_trail_version_count(dashboard.id)
      assert before_restore_count >= 2, "expected at least two versions after a build and a refine"

      # Main's review (10fd033, 2026-11-14): the editor's version list
      # and restore still run entirely on the hand-rolled
      # DashboardVersion table -- @dashboard_versions comes from
      # Dashboards.list_dashboard_versions/1, never paper_trail's own
      # versions table at all, even though Story 74 says versioning
      # uses paper_trail. A plain count match isn't decisive here: every
      # autosave writes one row to BOTH tables today, so their counts
      # always agree regardless of which one the UI actually reads from.
      # The ids don't -- DashboardVersion and PaperTrail.Version are
      # separate tables with separate sequences -- so compare the
      # rendered rows' own phx-value-id values against paper_trail's
      # real version ids, in the same order (most recent first).
      paper_trail_version_ids =
        Repo.query!(
          "select id from versions where item_type = 'Dashboard' and item_id = $1 order by id desc",
          [dashboard.id]
        ).rows
        |> List.flatten()

      rendered_versions =
        edit_view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("[data-role='dashboard-version']")

      rendered_version_ids =
        Enum.map(rendered_versions, fn row ->
          row
          |> Floki.find("button")
          |> Floki.attribute("phx-value-id")
          |> List.first()
          |> String.to_integer()
        end)

      assert rendered_version_ids == paper_trail_version_ids,
             "expected the rendered version ids to be paper_trail's own version ids, in the same order"

      # Restore the oldest listed version specifically (not whichever
      # [data-role='restore-version'] button element/2 happens to find
      # first -- there are now several, one per row) by reading its own
      # phx-value-id straight out of the rendered row and dispatching
      # the event directly.
      oldest_version_id =
        rendered_versions
        |> List.last()
        |> Floki.find("button")
        |> Floki.attribute("phx-value-id")
        |> List.first()

      render_click(edit_view, "restore_version", %{"id" => oldest_version_id})

      after_restore_count = paper_trail_version_count(dashboard.id)

      assert after_restore_count == before_restore_count + 1,
             "expected a restore to add exactly one paper_trail version, got #{before_restore_count} -> #{after_restore_count}"
    end)
  end

  test "a widget whose metric has no data in the queried range shows a clear message, not a silent 0 or blank chart",
       %{conn: conn} do
    stage("Ask for a dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)

      # Story 74 (main, live walk of a7ba770, 2026-11-14): a widget whose
      # query resolves to zero data points in the default 30-day range
      # should show a clear message, not silently render a 0 stat or an
      # empty chart. The metric still has to exist -- recorded 60 days
      # ago, outside the lookback -- so the dashboard chat can resolve it
      # rather than halting on an unresolvable-metric error. Today,
      # build_echarts_option/query_metric_values (editor.ex) just sum an
      # empty list to 0 and render an empty series/xAxis, with nothing
      # telling Dana there's no data here.
      insert_metric!(user, %{
        provider: :google_ads,
        metric_name: "impressions",
        value: 100.0,
        recorded_at: DateTime.new!(Date.add(Date.utc_today(), -60), ~T[00:00:00], "Etc/UTC")
      })

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.generate_initial()
      )

      render_submit(view, "send_dashboard_chat", %{
        "message" => "Show me impressions over time as a line chart"
      })

      html =
        wait_for(fn ->
          if has_element?(view, "[data-role='no-data-message']") do
            render(view)
          else
            nil
          end
        end)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(html),
             "expected a [data-role='no-data-message'] element for a widget with zero data points in range"

      assert html =~ "No data for this period"
    end)
  end

  test "the echarts-chart container is marked phx-update='ignore' so a LiveView patch can't wipe its canvas",
       %{conn: conn} do
    stage("Ask for a dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      # Main's live walk (a7ba770 + seeds, 2026-11-14): after any live
      # update (a chat refine, a filter change), the chart's <canvas> is
      # gone until a full reload -- LiveView's own patch wipes the DOM
      # the ECharts hook drew into, since nothing tells LiveView to leave
      # that element alone. A real browser is the only way to see the
      # canvas itself disappear; phx-update="ignore" on the hook
      # container is the structural fix this depends on and the one
      # thing checkable here without a browser.
      assert has_element?(view, "[data-role='echarts-chart'][phx-update='ignore']")
    end)
  end

  test "switching the date-range filter to 90 days changes the queried data, not just its label", %{
    conn: conn
  } do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)

      insert_metric!(user, %{
        provider: :google_ads,
        metric_name: "impressions",
        value: 100.0,
        recorded_at: DateTime.new!(Date.add(Date.utc_today(), -1), ~T[00:00:00.000000], "Etc/UTC")
      })

      insert_metric!(user, %{
        provider: :google_ads,
        metric_name: "impressions",
        value: 50.0,
        recorded_at: DateTime.new!(Date.add(Date.utc_today(), -60), ~T[00:00:00.000000], "Etc/UTC")
      })

      scope = Scope.for_user(user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, edit_view, _edit_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      total_at_30_days = edit_view |> render() |> stat_tile_total()

      edit_view
      |> element("[data-role='filter-control'] form[phx-change]")
      |> render_change(%{"range" => "90"})

      total_at_90_days = edit_view |> render() |> stat_tile_total()

      # Main's live walk (a7ba770 + seeds, 2026-11-14): at 90 days, both
      # charts still had the same 31 points and the stat was the same
      # 125706.0 as at 30 days, including after reopening -- the filter
      # only assigns :dashboard_date_range; resolve_chart_render/2
      # (editor.ex) queries Dashboards.default_date_range/0
      # unconditionally, so nothing ever re-queries on a wider range.
      # The 60-day-old row above only falls inside the 90-day window, so
      # a correct re-query must raise the total once the filter changes.
      assert total_at_90_days > total_at_30_days,
             "expected the 90-day total (#{total_at_90_days}) to exceed the 30-day total (#{total_at_30_days})"
    end)
  end

  test "a stat tile's total renders as a thousands-separated number, not a raw float", %{conn: conn} do
    stage("Ask for a dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 125_706.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      stat_text =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("[data-role='stat-tile-value']")
        |> Floki.text()
        |> String.trim()

      # Main's live walk (a7ba770 + seeds, 2026-11-14): the stat rendered
      # the raw summed float "125706.0" instead of "125,706" --
      # build_chart_render (editor.ex) interpolates the sum with no
      # formatting at all.
      assert stat_text == "125,706"
    end)
  end

  # ---------------------------------------------------------------------------
  # Story 75: Save, List and Reopen Dashboards (criteria 1068-1080)
  # ---------------------------------------------------------------------------

  test "the agent titles Dana's new dashboard from her request, and she can rename it from the list",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "clicks", value: 10.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.generate_titled_bar_chart()
      )

      render_submit(view, "send_dashboard_chat", %{
        "message" => "show me a bar chart of clicks by day"
      })

      wait_for_chart(view)

      Application.delete_env(:metric_flow, :command_runner)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      # Story 75, criterion 1068: "the dashboard has a title drawn from
      # her request." Main's live walk (3a78f72, 2026-11-14) found this
      # only half-true: the chat build named the dashboard with Dana's
      # raw request text verbatim ("Show me a bar chart of clicks by
      # day"), not a title the agent chose -- the request copied, not
      # titled. The stub's spec carries its own top-level "title",
      # worded differently from the request on purpose, so this only
      # passes once the dashboard's name actually comes from that
      # title rather than the message text.
      assert dashboard.name == "Daily Clicks",
             "expected the dashboard's title to come from the spec's own title, not the raw request text"

      {:ok, _index_view, index_html} = live(conn, ~p"/app/dashboards")

      assert index_html =~ "Daily Clicks"
      refute index_html =~ "show me a bar chart of clicks by day"

      # "...and she can rename it ... from the list." Settled and
      # built: data-role="rename-dashboard-#{id}".
      assert index_html =~ ~s(data-role="rename-dashboard-#{dashboard.id}")
    end)
  end

  test "the dashboard chat is told to give a chat-built dashboard a short title", %{conn: conn} do
    stage("Save and reopen", fn ->
      {:ok, agent} = Agent.start_link(fn -> nil end)

      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      Application.put_env(:metric_flow, :command_runner, capturing_runner(agent))

      render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions over time"})

      args = wait_for_capture(agent)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(args), "the dashboard chat never reached the command_runner"

      payload = decode_prompt_payload(args)

      set_dashboard_spec_tool =
        Enum.find(payload["available_tools"], &(&1["name"] == "set_dashboard_spec"))

      refute is_nil(set_dashboard_spec_tool), "expected set_dashboard_spec to be offered"

      description = set_dashboard_spec_tool["description"] || ""

      # Story 75, criterion 1068 (main, 2026-11-14): the model needs to
      # be told explicitly to choose a short title for the dashboard --
      # set_dashboard_spec's description says nothing about a "title"
      # field at all today.
      assert Regex.match?(~r/title/i, description),
             "expected set_dashboard_spec's description to tell the model to give the dashboard a short title"
    end)
  end

  test "deleting a dashboard with confirmation removes it, its chat history, and its versions",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)
      assert paper_trail_version_count(dashboard.id) > 0

      {:ok, index_view, _html} = live(conn, ~p"/app/dashboards")

      index_view
      |> element("[data-role='delete-dashboard-#{dashboard.id}']")
      |> render_click()

      index_view
      |> element("[data-role='confirm-delete-#{dashboard.id}']")
      |> render_click()

      refute has_element?(index_view, "[data-dashboard-id='#{dashboard.id}']")
      assert Dashboards.list_dashboards(scope) == []

      # Story 75, criterion 1069: "its chat history and versions are
      # gone." paper_trail's versions table has no foreign key to
      # dashboards at all (item_id/item_type are plain columns, no
      # on_delete), and the AI chat session is looked up separately by
      # (scope, :dashboard, id) -- Dashboards.delete_dashboard/2 just
      # does Repo.delete(dashboard), with no cleanup of either.
      assert paper_trail_version_count(dashboard.id) == 0,
             "expected the dashboard's versions to be deleted along with it"

      assert Ai.get_chat_session_by_context(scope, :dashboard, dashboard.id) == {:error, :not_found},
             "expected the dashboard's chat history to be deleted along with it"
    end)
  end

  test "cancelling the delete confirmation leaves the dashboard untouched", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, index_view, _html} = live(conn, ~p"/app/dashboards")

      index_view
      |> element("[data-role='delete-dashboard-#{dashboard.id}']")
      |> render_click()

      index_view
      |> element("[data-role='cancel-delete']")
      |> render_click()

      assert has_element?(index_view, "[data-dashboard-id='#{dashboard.id}']")
      assert Dashboards.list_dashboards(scope) == [dashboard]
    end)
  end

  test "duplicating a dashboard copies its spec and filter into a new dashboard, with no history",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)
      {:ok, dashboard} = Dashboards.update_dashboard(scope, dashboard, %{"date_range" => "90"})

      {:ok, index_view, _html} = live(conn, ~p"/app/dashboards")

      # Story 75, criterion 1071: no duplicate affordance exists in
      # dashboard_live/index.ex at all -- only View/Edit/Delete per
      # card. Selector proposed: data-role="duplicate-dashboard-#{id}".
      assert has_element?(index_view, "[data-role='duplicate-dashboard-#{dashboard.id}']")
    end)
  end

  test "a read-only member cannot start a dashboard", %{conn: conn} do
    stage("Save and reopen", fn ->
      owner = user_fixture()
      member = user_fixture()
      account = insert_account!(owner)
      insert_member!(account, owner, :owner)
      insert_member!(account, member, :read_only)

      conn = log_in_user(conn, member)

      result = live(conn, ~p"/app/dashboards/new")

      # Story 75, criterion 1072: "they are refused and no dashboard is
      # created." Role gating from story 8 is supposed to carry over to
      # the builder, but dashboard_live/editor.ex has no role or
      # permission check anywhere (confirmed via grep) -- a read-only
      # member mounts /dashboards/new exactly like an owner would.
      refute match?({:ok, _view, _html}, result),
             "expected a read-only member to be refused at /dashboards/new"

      assert Dashboards.list_dashboards(Scope.for_user(member)) == []
    end)
  end

  test "Dana can search her dashboards by name", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      scope = Scope.for_user(user)

      {:ok, _monday} = Dashboards.save_dashboard(scope, %{"name" => "Monday review"})
      {:ok, _spend} = Dashboards.save_dashboard(scope, %{"name" => "Ad spend"})
      {:ok, _traffic} = Dashboards.save_dashboard(scope, %{"name" => "Traffic"})

      conn = log_in_user(conn, user)

      {:ok, index_view, _html} = live(conn, ~p"/app/dashboards")

      # Story 75, criterion 1073: "searching 'ad' shows only 'Ad
      # spend'." No search input exists anywhere in dashboard_live/
      # index.ex. Selector proposed: data-role="dashboard-search".
      assert has_element?(index_view, "[data-role='dashboard-search']")

      index_view
      |> element("[data-role='dashboard-search'] form[phx-change]")
      |> render_change(%{"query" => "ad"})

      cards =
        index_view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("[data-role='dashboard-card']")

      assert length(cards) == 1
      assert Floki.text(hd(cards)) =~ "Ad spend"
    end)
  end

  test "a search that matches none of Dana's dashboards shows an empty result", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      scope = Scope.for_user(user)

      {:ok, _a} = Dashboards.save_dashboard(scope, %{"name" => "Monday review"})
      {:ok, _b} = Dashboards.save_dashboard(scope, %{"name" => "Ad spend"})
      {:ok, _c} = Dashboards.save_dashboard(scope, %{"name" => "Traffic"})

      conn = log_in_user(conn, user)

      {:ok, index_view, _html} = live(conn, ~p"/app/dashboards")

      assert has_element?(index_view, "[data-role='dashboard-search']")

      index_view
      |> element("[data-role='dashboard-search'] form[phx-change]")
      |> render_change(%{"query" => "payroll"})

      # Selector proposed: data-role="empty-search-results".
      assert has_element?(index_view, "[data-role='empty-search-results']")
    end)
  end

  test "Dana can mark a dashboard as a favorite and unmark it", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      scope = Scope.for_user(user)

      {:ok, dashboard} = Dashboards.save_dashboard(scope, %{"name" => "Monday review"})

      conn = log_in_user(conn, user)

      {:ok, index_view, _html} = live(conn, ~p"/app/dashboards")

      # Story 75, criterion 1075: no favorite field exists on the
      # Dashboard schema at all (confirmed via grep), so there's
      # nothing to toggle here. Selector proposed:
      # data-role="favorite-dashboard-#{id}".
      assert has_element?(index_view, "[data-role='favorite-dashboard-#{dashboard.id}']")
    end)
  end

  test "Dana sees built-in dashboards in their own section, apart from her own", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      scope = Scope.for_user(user)

      {:ok, _own} = Dashboards.save_dashboard(scope, %{"name" => "My dashboard"})

      conn = log_in_user(conn, user)

      {:ok, _index_view, html} = live(conn, ~p"/app/dashboards")

      canned_section =
        html |> Floki.parse_fragment!() |> Floki.find("[data-role='canned-dashboards']")

      user_section =
        html |> Floki.parse_fragment!() |> Floki.find("[data-role='user-dashboards']")

      # Story 75, criterion 1076: dashboard_live/index.ex already
      # renders canned and user dashboards in separate sections -- but
      # nothing currently shows up in the canned one, however built-ins
      # are meant to be sourced (today, Dashboards.list_canned_dashboards/0
      # queries for built_in: true rows, and none exist anywhere in this
      # tree yet).
      assert canned_section != [], "expected at least one built-in dashboard to be listed"
      assert user_section != []
    end)
  end

  test "opening a saved dashboard shows it with an Edit with agent button that opens the chat",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, show_view, _show_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      # Story 75, criterion 1077: "she sees the dashboard with her saved
      # filters and an Edit with agent button." DashboardLive.Show is
      # still the pre-A2UI "All Metrics" page (its own moduledoc says
      # so) -- it never renders a saved a2ui_spec's widgets and has no
      # Edit with agent button at all.
      assert has_element?(show_view, "[data-role='echarts-chart']")
      assert has_element?(show_view, "[data-role='edit-dashboard-#{dashboard.id}']")
    end)
  end

  test "the old /reports and /visualizations pages are gone", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)

      conn = log_in_user(conn, user)

      reports_result = live(conn, ~p"/app/reports")
      visualizations_result = live(conn, ~p"/app/visualizations")

      # Story 75, criterion 1078: both pages are retired in favor of
      # the one dashboards list; router.ex still registers
      # ReportLive.Index and VisualizationLive.Index under those paths,
      # so both still mount today instead of 404ing.
      refute match?({:ok, _view, _html}, reports_result),
             "expected /app/reports to be gone (404), but it still mounts"

      refute match?({:ok, _view, _html}, visualizations_result),
             "expected /app/visualizations to be gone (404), but it still mounts"

      {:ok, _index_view, index_html} = live(conn, ~p"/app/dashboards")

      refute index_html =~ ~s(href="/app/reports")
      refute index_html =~ ~s(href="/app/visualizations")
    end)
  end

  test "changing a dashboard's filter on the view page re-queries and persists it after a fresh mount",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)

      insert_metric!(user, %{
        provider: :google_ads,
        metric_name: "impressions",
        value: 100.0,
        recorded_at: DateTime.new!(Date.add(Date.utc_today(), -1), ~T[00:00:00.000000], "Etc/UTC")
      })

      insert_metric!(user, %{
        provider: :google_ads,
        metric_name: "impressions",
        value: 50.0,
        recorded_at: DateTime.new!(Date.add(Date.utc_today(), -60), ~T[00:00:00.000000], "Etc/UTC")
      })

      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, show_view, _show_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      assert has_element?(show_view, "[data-role='filter-control'] form[phx-change]")

      total_at_30_days = show_view |> render() |> stat_tile_total()

      # Main's review (4986f30, 2026-11-14): show.ex's date-range select
      # has phx-change="dashboard_filter_date_range", but
      # DashboardLive.Show defines no such handle_event -- changing it
      # crashes the LiveView process instead of re-querying anything or
      # persisting the choice. Exercising the real control here, not a
      # proxy for it: this is expected to crash until the handler
      # exists, reusing the editor's own persistence (Main's
      # instruction to the coder).
      show_view
      |> element("[data-role='filter-control'] form[phx-change]")
      |> render_change(%{"range" => "90"})

      total_at_90_days = show_view |> render() |> stat_tile_total()

      assert total_at_90_days > total_at_30_days,
             "expected the 90-day total (#{total_at_90_days}) to exceed the 30-day total (#{total_at_30_days})"

      {:ok, _reopened_view, reopened_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      assert reopened_html =~ ~s(value="90" selected)
    end)
  end

  test "a dashboard's versions are shown only in Edit with agent, not on the view page", %{
    conn: conn
  } do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)
      assert paper_trail_version_count(dashboard.id) > 0

      {:ok, show_view, _show_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      refute has_element?(show_view, "[data-role='dashboard-version-list']")

      # Story 75, criterion 1080: "choosing Edit with agent shows the
      # versions beside the chat." DashboardLive.Show has no Edit with
      # agent button to choose at all (same gap as criterion 1077).
      assert has_element?(show_view, "[data-role='edit-dashboard-#{dashboard.id}']")
    end)
  end

  test "a table widget renders as a table on the view page, not a line chart", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.generate_table_widget()
      )

      render_submit(view, "send_dashboard_chat", %{"message" => "show me a table of impressions"})

      refute is_nil(
               wait_for(fn ->
                 rendered = render(view)
                 if rendered =~ "added a table of impressions", do: rendered, else: nil
               end)
             ),
             "the table build never completed"

      Application.delete_env(:metric_flow, :command_runner)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, show_view, show_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      # Main's review (76d8303, 2026-11-14): show.ex's own
      # a2ui_component_chart_type has no "table" clause -- it falls
      # through to the "line" default, so a table widget renders as an
      # ECharts line chart on the view page instead of a table.
      card =
        show_html
        |> Floki.parse_fragment!()
        |> Floki.find("[data-role='visualization-card']")
        |> Enum.find(&(Floki.text(&1) =~ "Impressions"))

      refute is_nil(card), "expected an 'Impressions' card on the view page"

      assert Floki.find(card, "table thead th") |> Floki.text() =~ "Date"
      refute has_element?(show_view, "[data-role='echarts-chart']")
    end)
  end

  test "a dashboard's saved platform filter is applied on the view page", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      insert_metric!(user, %{provider: :facebook_ads, metric_name: "impressions", value: 10.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      # Simulates a platform filter already saved from the builder
      # (editor.ex's own "filter_platform" handler persists it the same
      # way) -- not something this test invents.
      {:ok, dashboard} =
        Dashboards.update_dashboard(scope, dashboard, %{"platform_filter" => "google_ads"})

      {:ok, _show_view, show_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      # Main's review (76d8303, 2026-11-14): the view page's
      # a2ui_query_values/3 only takes a date_range -- the saved
      # platform_filter is never passed to Metrics.query_time_series,
      # so the stat sums every platform's impressions (100 + 10 = 110)
      # instead of only the saved one (100).
      assert stat_tile_total(show_html) == 100.0,
             "expected the view page to apply the saved platform filter (google_ads only)"
    end)
  end

  test "changing the platform filter on the view page re-queries and persists it", %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      insert_metric!(user, %{provider: :facebook_ads, metric_name: "impressions", value: 10.0})
      scope = Scope.for_user(user)

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, show_view, _show_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      # Main's review (76d8303, 2026-11-14): the view page has no
      # platform-filter control at all, unlike the builder's own
      # [data-role='platform-filter'] (editor.ex) -- there's nothing to
      # change the platform through on this page today.
      assert has_element?(show_view, "[data-role='platform-filter']")

      render_click(show_view, "filter_platform", %{"platform" => "google_ads"})

      filtered_html = render(show_view)
      assert stat_tile_total(filtered_html) == 100.0

      {:ok, _reopened_view, reopened_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      assert stat_tile_total(reopened_html) == 100.0,
             "expected the platform choice to persist across a fresh mount"
    end)
  end

  test "a legacy dashboard (Visualization rows, no a2ui_spec) opens on the view page with its widgets",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})
      scope = Scope.for_user(user)

      {:ok, dashboard} = Dashboards.save_dashboard(scope, %{"name" => "Legacy Dashboard"})

      :ok =
        Dashboards.replace_dashboard_visualizations(scope, dashboard, [
          %{metric_name: "impressions", chart_type: "line", position: 0}
        ])

      conn = log_in_user(conn, user)

      # Main's review (03d915c, 2026-11-14): a dashboard saved before
      # Story 74's A2UI rebuild (Visualization rows, a2ui_spec nil)
      # crashes the view page outright with "comparing
      # m.normalized_metric_name with nil is forbidden". Root cause:
      # a2ui_dashboard_components/1 derives a legacy component straight
      # from the Visualization's raw vega_spec (the ad-hoc
      # %{"metric_name" => _, "chart_type" => _} shape,
      # replace_dashboard_visualizations/3's own default), but then
      # calls the shared A2ui.component_metric/1 on it -- which only
      # understands the chat-built {"query" => {"metric" => _}} shape
      # and returns nil for this one, unlike the editor's own
      # chart_metric_key/1, which already resolves this legacy shape
      # without going through nil.
      assert {:ok, _view, html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")
      assert html =~ "Impressions"
    end)
  end

  test "a table widget's values show up to 2 decimal places and thousands grouping, on both the editor and the view page",
       %{conn: conn} do
    stage("Save and reopen", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)

      insert_metric!(user, %{
        provider: :google_ads,
        metric_name: "impressions",
        value: 0.034,
        recorded_at: DateTime.new!(Date.add(Date.utc_today(), -5), ~T[00:00:00], "Etc/UTC")
      })

      insert_metric!(user, %{
        provider: :google_ads,
        metric_name: "impressions",
        value: 12.5,
        recorded_at: DateTime.new!(Date.add(Date.utc_today(), -10), ~T[00:00:00], "Etc/UTC")
      })

      insert_metric!(user, %{
        provider: :google_ads,
        metric_name: "impressions",
        value: 4005,
        recorded_at: DateTime.new!(Date.add(Date.utc_today(), -15), ~T[00:00:00], "Etc/UTC")
      })

      scope = Scope.for_user(user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.DashboardBuilderStub.generate_table_widget()
      )

      render_submit(view, "send_dashboard_chat", %{"message" => "show me a table of impressions"})

      refute is_nil(
               wait_for(fn ->
                 rendered = render(view)
                 if rendered =~ "added a table of impressions", do: rendered, else: nil
               end)
             ),
             "the table build never completed"

      Application.delete_env(:metric_flow, :command_runner)

      # Main's review (bb0056d, 2026-11-14): A2ui.format_table_value/1
      # rounded every value with round() |> Integer.to_string() -- a
      # fractional metric (0.034, 12.5) should show up to 2 decimal
      # places ("0.03", "12.50"), not be rounded to a whole number.
      # Extended (main, 2026-11-14) to cover the coder's unified
      # format_number/1 (601995f) end to end: a large whole value
      # (4005) in the same table should also show thousands grouping
      # ("4,005"), matching the stat tile's own formatting. Editor and
      # Show both render a table widget through the one shared
      # widget_card component and the one shared
      # A2ui.render_from_values/2, so checking both pages against the
      # same seeded data checks the one place this is actually fixed.
      editor_html = render(view)
      assert editor_html =~ "0.03"
      assert editor_html =~ "12.50"
      assert editor_html =~ "4,005"

      assert [dashboard] = Dashboards.list_dashboards(scope)

      {:ok, _show_view, show_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}")

      assert show_html =~ "0.03"
      assert show_html =~ "12.50"
      assert show_html =~ "4,005"
    end)
  end
end
