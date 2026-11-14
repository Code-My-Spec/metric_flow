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
      assert has_element?(view, "[data-role='vega-lite-chart']")
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
        MetricFlowTest.VizChatStub.generate_initial()
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
      assert reopened_html =~ ~s(data-role="vega-lite-chart")
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
    end)
  end

  test "the dashboard chat tells the model it can call update_spec once per widget", %{
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
      # dashboard elements. The backend mechanism exists (two update_spec
      # calls -> two elements, confirmed by the test above). This asserts on
      # the actual prompt/tool text the dashboard chat sends on this path --
      # via a capturing command_runner driven through the same LiveView event
      # the live app uses, not a scripted response -- so it only passes once
      # that guidance (or a dedicated add-widget tool) genuinely reaches the
      # model here.
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
        MetricFlowTest.VizChatStub.generate_followup()
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
        MetricFlowTest.VizChatStub.generate_followup()
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

  test "refining an existing widget replaces it instead of duplicating it", %{conn: conn} do
    stage("Refine the dashboard", fn ->
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions", value: 100.0})

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/dashboards/new")
      build_chart_via_chat(view)

      cards_before =
        view |> render() |> Floki.parse_fragment!() |> Floki.find("[data-role='visualization-card']")

      assert length(cards_before) == 2

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.VizChatStub.refine_to_area_chart()
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

      # Story 74 rules 2/4 (refining an existing widget): confirmed live
      # by main (2026-11-14, 5ee7d7c on dashboard 11): asked to change
      # "Impressions Over Time" from a line chart to an area chart, the
      # agent replied it changed it, but the canvas gained a THIRD card
      # (was 2) -- both the original line-chart card and a new area-chart
      # card remained. Root cause: add_visualizations_from_chat_specs/2
      # unconditionally appends every update_spec call's result;
      # update_spec's own input_schema has no id/index/target parameter at
      # all, so the only signal available to identify "the existing
      # widget" is the spec's own "title" (extract_chat_metric_name/1).
      # The stub here reproduces exactly what the real model does: calls
      # update_spec once with a new spec sharing the existing widget's
      # title ("Impressions Over Time") but a different mark.
      assert length(cards_after) == 2

      impressions_card = Enum.find(cards_after, &(Floki.text(&1) =~ "Impressions Over Time"))
      refute is_nil(impressions_card), "expected an 'Impressions Over Time' card to remain"

      badge_text = impressions_card |> Floki.find(".badge") |> Floki.text() |> String.trim()
      assert badge_text == "area"
    end)
  end

  test "refining an existing widget replaces it even when the model rewords its title", %{
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

      cards_before =
        view |> render() |> Floki.parse_fragment!() |> Floki.find("[data-role='visualization-card']")

      assert length(cards_before) == 2

      Application.put_env(
        :metric_flow,
        :command_runner,
        MetricFlowTest.VizChatStub.refine_to_area_chart_with_reworded_title()
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

      # Story 74 rules 2/4, criterion 1062: refining an existing widget
      # should update it in place, not duplicate it, even when the model
      # renames it in the same response. merge_chat_specs/3 (8b62d9c)
      # matched only by exact title, so a rename alone would have missed
      # and duplicated -- that gap is why this test originally existed.
      # df2bd49 added a stable widget_id per existing widget specifically
      # so a rename can't break the match; this stub now supplies
      # widget_id: 1 (the line chart's position) alongside the reworded
      # title, modeling a model that does what it's told. See the
      # capture-based test below for whether the model is actually told
      # to do that.
      assert length(cards_after) == 2

      reworded_card = Enum.find(cards_after, &(Floki.text(&1) =~ "Daily Impressions"))
      refute is_nil(reworded_card), "expected a 'Daily Impressions' card after the rename"

      badge_text = reworded_card |> Floki.find(".badge") |> Floki.text() |> String.trim()
      assert badge_text == "area"
    end)
  end

  test "existing widgets are given a stable id, and the model is told to use it", %{
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

      {:ok, agent} = Agent.start_link(fn -> nil end)

      Application.put_env(:metric_flow, :command_runner, capturing_runner(agent))

      render_submit(view, "send_dashboard_chat", %{"message" => "Make the line thicker"})

      args = wait_for_capture(agent)

      Application.delete_env(:metric_flow, :command_runner)

      refute is_nil(args), "the dashboard chat never reached the command_runner"

      payload = decode_prompt_payload(args)

      # Story 74 rules 2/4, criterion 1062 (widget_id mechanism, df2bd49):
      # a rename alone can't break the merge if the model is told to pass
      # back the widget_id it was given for the widget it's changing.
      # Asserts on the real payload the dashboard chat sends -- not a
      # scripted response -- so this only passes once (a) each existing
      # widget in the prompt actually carries a widget_id, and (b)
      # update_spec's own tool description tells the model to pass that
      # widget_id back to update in place.
      system_prompt_text = payload["system_prompt"] || ""

      assert system_prompt_text =~ ~r/widget_id/,
             "expected the existing widgets in the system prompt to carry a widget_id"

      update_spec_tool = Enum.find(payload["available_tools"], &(&1["name"] == "update_spec"))
      update_spec_description = update_spec_tool["description"] || ""

      assert Regex.match?(~r/widget_id.{0,120}(update|change).{0,20}in place/is, update_spec_description) or
               Regex.match?(~r/(update|change).{0,20}in place.{0,120}widget_id/is, update_spec_description),
             "expected update_spec's description to tell the model to pass widget_id to update a widget in place"
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
      # This only asserts the negative half (no Vega-Lite rendering
      # remnant survives a chat build); it does not assert an ECharts
      # container exists, since no ECharts markup convention has been
      # established anywhere in this codebase yet -- see journey_result.md
      # Journey 6 and the question raised to main about A2UI/ECharts
      # specifics not yet being settled.
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
end
