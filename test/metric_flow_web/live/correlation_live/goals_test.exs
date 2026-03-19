defmodule MetricFlowWeb.CorrelationLive.GoalsTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp create_personal_account!(user) do
    {:ok, account} =
      %Account{}
      |> Account.creation_changeset(%{
        name: "#{user.email} Personal",
        slug: unique_slug(),
        type: "personal",
        originator_user_id: user.id
      })
      |> Repo.insert()

    %AccountMember{}
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: :owner
    })
    |> Repo.insert!()

    account
  end

  defp user_with_personal_account do
    user = user_fixture()
    account = create_personal_account!(user)
    {user, account}
  end

  defp insert_completed_job!(account_id, attrs) do
    defaults = %{
      account_id: account_id,
      status: :completed,
      goal_metric_name: "revenue",
      data_window_start: ~D[2026-01-01],
      data_window_end: ~D[2026-01-31],
      data_points: 90,
      results_count: 3,
      started_at: ~U[2026-01-31 10:00:00.000000Z],
      completed_at: ~U[2026-01-31 10:05:00.000000Z]
    }

    %CorrelationJob{}
    |> CorrelationJob.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_running_job!(account_id) do
    %CorrelationJob{}
    |> CorrelationJob.changeset(%{
      account_id: account_id,
      status: :running,
      goal_metric_name: "revenue",
      started_at: ~U[2026-01-31 10:00:00.000000Z]
    })
    |> Repo.insert!()
  end

  # Inserts 35 daily records for two metrics to satisfy the 30-day data
  # requirement for Correlations.run_correlations/2.
  defp insert_sufficient_metrics!(user) do
    yesterday = Date.add(Date.utc_today(), -1)

    Enum.each(1..35, fn i ->
      date = Date.add(yesterday, -i)

      %Metric{}
      |> Metric.changeset(%{
        user_id: user.id,
        metric_type: "revenue",
        metric_name: "revenue",
        value: 1000.0 + i,
        recorded_at: DateTime.new!(date, ~T[00:00:00], "Etc/UTC"),
        provider: :google_analytics,
        dimensions: %{}
      })
      |> Repo.insert!()

      %Metric{}
      |> Metric.changeset(%{
        user_id: user.id,
        metric_type: "advertising",
        metric_name: "clicks",
        value: 50.0 + i,
        recorded_at: DateTime.new!(date, ~T[00:00:00], "Etc/UTC"),
        provider: :google_ads,
        dimensions: %{}
      })
      |> Repo.insert!()
    end)
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the goal metric page for an authenticated user", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations/goals")

        assert is_binary(html)
      end)
    end

    test "shows page title 'Goal Metric'", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations/goals")

        assert html =~ "Goal Metric"
      end)
    end

    test "shows subtitle 'Choose the metric the correlation engine targets.'", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations/goals")

        assert html =~ "Choose the metric the correlation engine targets."
      end)
    end

    test "renders the save goal button", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        assert has_element?(lv, "[data-role='save-goal']")
      end)
    end

    test "renders the cancel button", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        assert has_element?(lv, "[data-role='cancel']")
      end)
    end

    test "renders the goal metric select dropdown", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "sessions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        assert has_element?(lv, "select")
      end)
    end

    test "populates the dropdown with metric names from list_metric_names/1", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "sessions"})
      insert_metric!(user, %{metric_name: "revenue"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations/goals")

        assert html =~ "sessions"
        assert html =~ "revenue"
      end)
    end

    test "pre-selects the goal_metric_name from the latest correlation summary", %{conn: conn} do
      {user, account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "revenue"})
      insert_metric!(user, %{metric_name: "clicks"})
      insert_completed_job!(account.id, %{goal_metric_name: "revenue"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations/goals")

        assert html =~ "revenue"
      end)
    end

    test "shows empty state message when no metrics are available", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations/goals")

        assert html =~ "No metrics available"
      end)
    end

    test "shows placeholder option when metric_names is empty", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations/goals")

        assert html =~ "No metrics available — sync data first"
      end)
    end

    test "save goal button is disabled when metric_names is empty", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        assert has_element?(lv, "[data-role='save-goal'][disabled]")
      end)
    end

    test "shows Connect Integrations link in empty state", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        assert has_element?(lv, "a[href='/integrations']")
      end)
    end

    test "redirects unauthenticated user to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/correlations/goals")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"select_goal\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"select_goal\"" do
    test "renders successfully after the change event", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "sessions"})
      insert_metric!(user, %{metric_name: "clicks"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        html = render_change(lv, "select_goal", %{"goal_metric_name" => "clicks"})

        assert is_binary(html)
      end)
    end

    test "reflects the newly chosen metric in the rendered output after change event", %{
      conn: conn
    } do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "sessions"})
      insert_metric!(user, %{metric_name: "clicks"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "clicks"})

        assert render(lv) =~ "clicks"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"save_goal\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"save_goal\"" do
    test "redirects to /correlations on successful save", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_sufficient_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})

        lv
        |> form("form")
        |> render_submit()

        {path, _flash} = assert_redirect(lv)
        assert path == "/correlations"
      end)
    end

    test "flashes info message 'Goal metric saved. Correlation analysis started.' on success", %{
      conn: conn
    } do
      {user, _account} = user_with_personal_account()
      insert_sufficient_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})

        lv
        |> form("form")
        |> render_submit()

        flash = assert_redirect(lv, ~p"/correlations")
        assert flash["info"] =~ "Goal metric saved. Correlation analysis started."
      end)
    end

    test "redirects to /correlations when a correlation run is already in progress", %{
      conn: conn
    } do
      {user, account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "revenue"})
      insert_metric!(user, %{metric_name: "clicks"})
      insert_running_job!(account.id)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})

        lv
        |> form("form")
        |> render_submit()

        {path, _flash} = assert_redirect(lv)
        assert path == "/correlations"
      end)
    end

    test "flashes info message 'A correlation run is already in progress.' when already running",
         %{conn: conn} do
      {user, account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "revenue"})
      insert_metric!(user, %{metric_name: "clicks"})
      insert_running_job!(account.id)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})

        lv
        |> form("form")
        |> render_submit()

        flash = assert_redirect(lv, ~p"/correlations")
        assert flash["info"] =~ "A correlation run is already in progress."
      end)
    end

    test "shows error flash and stays on page when insufficient data", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "revenue"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})

        html =
          lv
          |> form("form")
          |> render_submit()

        assert html =~ "Not enough data"
      end)
    end

    test "shows full error message when insufficient data", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "revenue"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})

        html =
          lv
          |> form("form")
          |> render_submit()

        assert html =~ "at least 30 days of metrics required"
      end)
    end

    test "keeps the form visible after insufficient data error", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "revenue"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})

        lv
        |> form("form")
        |> render_submit()

        assert has_element?(lv, "form")
        assert has_element?(lv, "[data-role='save-goal']")
      end)
    end

    # When no metrics are available, selected_goal defaults to "" at mount.
    # Submitting the form in this state triggers the empty-selection guard.
    test "shows error flash when selected_goal is empty", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        html = render_submit(lv, "save_goal", %{})

        assert html =~ "Please select a goal metric."
      end)
    end

    test "keeps form visible after empty selection error", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_submit(lv, "save_goal", %{})

        assert has_element?(lv, "form")
        assert has_element?(lv, "[data-role='save-goal']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"cancel\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"cancel\"" do
    test "navigates to /correlations when cancel is clicked", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        lv
        |> element("[data-role='cancel']")
        |> render_click()

        assert_redirect(lv, ~p"/correlations")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/correlations/goals")
    end
  end
end
