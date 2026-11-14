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
      assert length(components) > 0
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

      assert length(chart_or_stat_components) > 0

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

  test "restoring a dashboard version adds a row to paper_trail's versions table", %{conn: conn} do
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

      # Story 74's notes (get_story 74): versioning uses the paper_trail
      # dependency on the dashboard blob; restore creates a new version.
      # paper_trail is not a dependency yet (confirmed: no match in
      # mix.lock/mix.exs), so its "versions" table cannot exist either.
      # to_regclass returns NULL for a missing relation rather than
      # raising, so this fails as a clear assertion, not a crash.
      result = Repo.query!("select to_regclass('versions')")
      assert [[regclass]] = result.rows

      refute is_nil(regclass),
             "expected a paper_trail 'versions' table to exist (dependency not yet added)"

      # Unreachable until the guard above passes: restoring an earlier
      # version should insert a new paper_trail version row scoped to
      # this dashboard.
      {:ok, edit_view, _edit_html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      edit_view
      |> element("[data-role='restore-version']")
      |> render_click()

      %{rows: [[count]]} =
        Repo.query!(
          "select count(*) from versions where item_type = 'Dashboard' and item_id = $1",
          [dashboard.id]
        )

      assert count > 0
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
end
