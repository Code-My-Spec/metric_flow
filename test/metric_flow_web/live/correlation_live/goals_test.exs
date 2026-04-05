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
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: :owner})
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

  defp insert_sufficient_metrics!(user) do
    yesterday = Date.add(Date.utc_today(), -1)

    Enum.each(1..35, fn i ->
      date = Date.add(yesterday, -i)

      %Metric{}
      |> Metric.changeset(%{
        user_id: user.id, metric_type: "revenue", metric_name: "revenue",
        value: 1000.0 + i, recorded_at: DateTime.new!(date, ~T[00:00:00], "Etc/UTC"),
        provider: :google_analytics, dimensions: %{}
      })
      |> Repo.insert!()

      %Metric{}
      |> Metric.changeset(%{
        user_id: user.id, metric_type: "advertising", metric_name: "clicks",
        value: 50.0 + i, recorded_at: DateTime.new!(date, ~T[00:00:00], "Etc/UTC"),
        provider: :google_ads, dimensions: %{}
      })
      |> Repo.insert!()
    end)
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders goals page with goal metric form and dropdown" do
    test "renders goals page with goal metric form and dropdown", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "sessions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/correlations/goals")

        assert html =~ "Goal Metric"
        assert has_element?(lv, "select")
        assert has_element?(lv, "[data-role='save-goal']")
        assert has_element?(lv, "[data-role='cancel']")
      end)
    end
  end

  describe "pre-selects the current goal metric from the latest correlation summary" do
    test "pre-selects the current goal metric from the latest correlation summary", %{conn: conn} do
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
  end

  describe "shows empty state with connect integrations link when no metrics exist" do
    test "shows empty state with connect integrations link when no metrics exist", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/correlations/goals")

        assert html =~ "No metrics available"
        assert has_element?(lv, "a[href='/integrations']")
      end)
    end
  end

  describe "disables save button when no metrics are available" do
    test "disables save button when no metrics are available", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        assert has_element?(lv, "[data-role='save-goal'][disabled]")
      end)
    end
  end

  describe "updates selected goal on dropdown change" do
    test "updates selected goal on dropdown change", %{conn: conn} do
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

  describe "saves goal metric and redirects to correlations with success flash" do
    test "saves goal metric and redirects to correlations with success flash", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_sufficient_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})
        lv |> form("form") |> render_submit()

        flash = assert_redirect(lv, ~p"/correlations")
        assert flash["info"] =~ "Goal metric saved. Correlation analysis started."
      end)
    end
  end

  describe "shows error flash when saving with no metric selected" do
    test "shows error flash when saving with no metric selected", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        html = render_submit(lv, "save_goal", %{})

        assert html =~ "Please select a goal metric."
        assert has_element?(lv, "form")
      end)
    end
  end

  describe "shows error flash when insufficient data for correlation" do
    test "shows error flash when insufficient data for correlation", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      insert_metric!(user, %{metric_name: "revenue"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})
        html = lv |> form("form") |> render_submit()

        assert html =~ "Not enough data"
        assert html =~ "at least 30 days of metrics required"
        assert has_element?(lv, "form")
      end)
    end
  end

  describe "navigates back to correlations on cancel click" do
    test "navigates back to correlations on cancel click", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations/goals")

        lv |> element("[data-role='cancel']") |> render_click()

        assert_redirect(lv, ~p"/correlations")
      end)
    end
  end
end
