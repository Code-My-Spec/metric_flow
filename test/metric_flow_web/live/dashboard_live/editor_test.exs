defmodule MetricFlowWeb.DashboardLive.EditorTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Dashboards
  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp render_until(lv, text, tries \\ 40) do
    html = render(lv)

    if html =~ text or tries == 0 do
      html
    else
      Process.sleep(50)
      render_until(lv, text, tries - 1)
    end
  end

  defp dashboard_fixture(user, attrs \\ %{}) do
    defaults = %{
      name: "My Test Dashboard #{System.unique_integer([:positive])}",
      user_id: user.id,
      account_id: MetricFlowTest.UsersFixtures.default_account_id(user.id)
    }

    %Dashboard{}
    |> Dashboard.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_account!(user, attrs \\ %{}) do
    defaults = %{
      name: "Test Account",
      slug: "account-#{System.unique_integer([:positive])}",
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

  # A command_runner scripting exactly one set_dashboard_spec tool call (the
  # dashboard chat's only write tool, Story 74) followed by its completion text.
  defp set_dashboard_spec_stub(
         spec,
         completion_text \\ "I'll create a line chart showing impressions over time."
       ) do
    MetricFlowTest.ClaudeCodeStub.sequence(
      MetricFlowTest.ClaudeCodeStub.completed_tool_call(
        "set_dashboard_spec",
        %{"a2ui_json" => Jason.encode!(spec)},
        completion_text: completion_text
      )
    )
  end

  defp line_chart_spec do
    %{
      "components" => [
        %{
          "id" => "widget-0",
          "type" => "chart",
          "title" => "Impressions Over Time",
          "chartType" => "line",
          "query" => %{"metric" => "impressions"}
        }
      ]
    }
  end

  defp two_widget_spec do
    %{
      "components" => [
        %{
          "id" => "widget-0",
          "type" => "stat",
          "title" => "Total Impressions",
          "query" => %{"metric" => "impressions"}
        },
        %{
          "id" => "widget-1",
          "type" => "chart",
          "title" => "Impressions Over Time",
          "chartType" => "line",
          "query" => %{"metric" => "impressions"}
        }
      ]
    }
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders new dashboard editor with name field and save button" do
    test "renders new dashboard editor with name field and save button", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/dashboards/new")

        assert html =~ "New Dashboard"
        assert has_element?(lv, "[data-role='dashboard-name-input']")
        assert has_element?(lv, "[data-role='save-dashboard-btn']")
      end)
    end
  end

  describe "renders edit dashboard editor loading existing dashboard data" do
    test "renders edit dashboard editor loading existing dashboard data", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user, %{name: "My Existing Dashboard"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

        assert html =~ "Edit Dashboard"
        assert html =~ "My Existing Dashboard"
      end)
    end
  end

  describe "validates dashboard name on change and shows inline error for blank name" do
    test "validates dashboard name on change and shows inline error for blank name", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboards/new")

        html = render_change(lv, "validate_name", %{"dashboard" => %{"name" => ""}})
        assert html =~ "can&#39;t be blank"
      end)
    end
  end

  describe "saves dashboard and navigates to show page with success flash" do
    test "saves dashboard and navigates to show page with success flash", %{conn: conn} do
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{metric_name: "impressions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          set_dashboard_spec_stub(line_chart_spec())
        )

        render_submit(lv, "send_dashboard_chat", %{
          "message" => "Show me impressions over time as a line chart"
        })

        # The agent replies from a task and autosaves a draft (patching to
        # /edit); wait for both before saving, so the patch isn't mistaken
        # for the save's redirect.
        render_until(lv, "I&#39;ll create a line chart showing impressions over time.")
        assert_patch(lv)
        Application.delete_env(:metric_flow, :command_runner)

        render_change(lv, "validate_name", %{"dashboard" => %{"name" => "My New Dashboard"}})

        lv |> element("[data-role='save-dashboard-btn']") |> render_click()

        assert_redirect(lv)
      end)
    end
  end

  describe "shows error when saving with no visualizations added" do
    test "shows error when saving with no visualizations added", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboards/new")

        render_change(lv, "validate_name", %{"dashboard" => %{"name" => "My Dashboard"}})

        html =
          lv |> element("[data-role='save-dashboard-btn']") |> render_click()

        assert html =~ "add at least one visualization"
      end)
    end
  end

  describe "redirects to dashboard with error when editing non-existent dashboard" do
    test "redirects to dashboard with error when editing non-existent dashboard", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        assert {:error, {:redirect, _}} = live(conn, ~p"/app/dashboards/999999/edit")
      end)
    end
  end

  describe "send_dashboard_chat with no metrics available" do
    test "shows integration guidance instead of calling the agent", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboards/new")

        html =
          render_submit(lv, "send_dashboard_chat", %{"message" => "Show me traffic"})

        assert html =~ "No metrics are available yet"
        refute has_element?(lv, "[data-role='visualization-card']")
      end)
    end
  end

  describe "send_dashboard_chat with metrics available" do
    test "builds a visualization from the agent's response and shows the exchange in the chat panel",
         %{conn: conn} do
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{metric_name: "impressions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          set_dashboard_spec_stub(line_chart_spec())
        )

        render_submit(lv, "send_dashboard_chat", %{
          "message" => "Show me impressions over time as a line chart"
        })

        # The agent replies from a task; wait for it rather than a fixed sleep.
        html = render_until(lv, "I&#39;ll create a line chart showing impressions over time.")

        Application.delete_env(:metric_flow, :command_runner)

        assert html =~ "Show me impressions over time as a line chart"
        assert html =~ "I&#39;ll create a line chart showing impressions over time."
        assert has_element?(lv, "[data-role='visualization-card']")
      end)
    end
  end

  describe "filter_date_range persists and survives a reopen" do
    test "changing the date range through its form updates the dashboard and survives a reopen",
         %{conn: conn} do
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{metric_name: "impressions"})
      scope = MetricFlowTest.UsersFixtures.account_scope_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          set_dashboard_spec_stub(line_chart_spec())
        )

        render_submit(lv, "send_dashboard_chat", %{
          "message" => "Show me impressions over time as a line chart"
        })

        Process.sleep(100)
        Application.delete_env(:metric_flow, :command_runner)

        assert [dashboard] = Dashboards.list_dashboards(scope)

        # A real browser only sends phx-change from inside a <form>; select by
        # the form itself (as the browser's change event bubbles to) rather
        # than the select, so this fails the way main's live walk did if the
        # control ever loses its wrapping form again.
        lv
        |> element("form[phx-change='filter_date_range']")
        |> render_change(%{"range" => "90"})

        {:ok, _reopened_view, reopened_html} =
          live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

        assert reopened_html =~ ~s(value="90" selected)
      end)
    end
  end

  describe "the editor highlights the saved platform filter on a fresh mount" do
    test "a dashboard saved with a platform filter highlights that platform, not 'All' (issue f50d37e9)",
         %{conn: conn} do
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{provider: :google_ads, metric_name: "impressions"})
      insert_metric!(user, %{provider: :facebook_ads, metric_name: "clicks"})
      dashboard = dashboard_fixture(user, %{platform_filter: "facebook_ads"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/app/dashboards/#{dashboard.id}/edit")

      # Before the fix, platform_filter was assigned as the raw DB string
      # while the shared component compares against atoms, so no button
      # matched -- not even "All".
      assert has_element?(lv, "button[phx-value-platform='facebook_ads'].btn-primary")
      refute has_element?(lv, "button[phx-value-platform='all'].btn-primary")
    end
  end

  describe "design pass: controls and preview are visibly separated" do
    test "save is the brand-gradient primary and the page splits controls from preview",
         %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/dashboards/new")

        # Save Dashboard is the one main action on this page -- DESIGN.md's
        # Primary button spec reserves the brand gradient for that role, not
        # a small daisyUI btn btn-primary.
        assert has_element?(lv, "[data-role='save-dashboard-btn'].btn-brand-gradient")

        # Controls (what the marketer edits) and Preview (what the dashboard
        # looks like) are two visibly separate regions so a 390px reader can
        # tell them apart.
        assert has_element?(lv, "section[data-role='editor-controls']")
        assert has_element?(lv, "section[data-role='editor-preview']")

        # The old undefined mf-card panel class (no matching CSS rule, so
        # nothing drew) is gone in favour of DESIGN.md Card tokens on
        # every panel this page owns.
        refute html =~ "mf-card"

        # The outer column carries overflow-x-hidden so nothing can push
        # the page sideways at 390 even as narrow chat and canvas content
        # wraps.
        assert html =~ "overflow-x-hidden"
      end)
    end
  end

  describe "refining an existing dashboard through chat replaces it with the model's complete new spec" do
    test "a refine turn's returned spec becomes the dashboard's new components, not an addition",
         %{conn: conn} do
      user = user_fixture()
      account = insert_account!(user)
      insert_member!(account, user, :owner)
      insert_metric!(user, %{metric_name: "impressions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboards/new")

        initial_spec = two_widget_spec()

        Application.put_env(:metric_flow, :command_runner, set_dashboard_spec_stub(initial_spec))

        render_submit(lv, "send_dashboard_chat", %{
          "message" => "Show me impressions, a stat tile and a line chart"
        })

        Process.sleep(100)

        # Story 74: set_dashboard_spec always carries the COMPLETE spec, so
        # a "refine" is nothing but the model returning a new full spec --
        # there is no id/title matching left on the app side to exercise.
        # Keeping the stat tile untouched and only changing the chart's
        # type proves the model's own echo is what makes a refine land
        # "in place" rather than as a third, additional card.
        refined_spec =
          put_in(initial_spec, ["components", Access.at(1), "chartType"], "area")

        Application.put_env(
          :metric_flow,
          :command_runner,
          set_dashboard_spec_stub(refined_spec, "I've changed it to an area chart.")
        )

        render_submit(lv, "send_dashboard_chat", %{
          "message" => "Change Impressions Over Time to an area chart"
        })

        Process.sleep(100)
        html = render(lv)

        Application.delete_env(:metric_flow, :command_runner)

        cards =
          html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='visualization-card']")

        assert length(cards) == 2
        assert html =~ "Total Impressions"
        assert html =~ "Impressions Over Time"
        assert html =~ "badge-ghost badge-sm\">area<"
        refute html =~ "badge-ghost badge-sm\">line<"
      end)
    end
  end
end
