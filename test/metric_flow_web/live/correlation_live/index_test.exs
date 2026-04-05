defmodule MetricFlowWeb.CorrelationLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Correlations.CorrelationResult
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

  defp insert_completed_job!(account_id, attrs \\ %{}) do
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

  defp insert_correlation_result!(account_id, job, attrs \\ %{}) do
    defaults = %{
      account_id: account_id,
      correlation_job_id: job.id,
      metric_name: "clicks",
      goal_metric_name: "revenue",
      coefficient: 0.82,
      optimal_lag: 7,
      data_points: 90,
      provider: :google_ads,
      calculated_at: ~U[2026-01-31 10:05:00.000000Z]
    }

    %CorrelationResult{}
    |> CorrelationResult.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders correlations page with header, mode toggle, and Run Now button" do
    test "renders correlations page with header, mode toggle, and Run Now button", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/correlations")

        assert html =~ "Correlations"
        assert has_element?(lv, "[data-role='mode-toggle']")
        assert has_element?(lv, "[data-role='run-correlations']")
      end)
    end
  end

  describe "shows no-data empty state when no correlation results exist" do
    test "shows no-data empty state when no correlation results exist", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/correlations")

        assert html =~ "No Correlations Yet"
        assert has_element?(lv, "[data-role='no-data-state']")
      end)
    end
  end

  describe "displays raw mode results table with metric, coefficient, lag, and platform columns" do
    test "displays raw mode results table with metric, coefficient, lag, and platform columns", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(account.id)
      insert_correlation_result!(account.id, job, %{metric_name: "clicks", coefficient: 0.82, optimal_lag: 7, provider: :google_ads})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='results-table']")
        assert has_element?(lv, "[data-role='correlation-row'][data-metric='clicks']")
        assert html =~ "clicks"
        assert html =~ "Google Ads"
        assert has_element?(lv, "[data-role='strength-badge']")
      end)
    end
  end

  describe "shows correlation summary bar with goal metric and data window" do
    test "shows correlation summary bar with goal metric and data window", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(account.id, %{goal_metric_name: "revenue"})
      insert_correlation_result!(account.id, job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='correlation-summary']")
        assert has_element?(lv, "[data-role='goal-metric']")
        assert has_element?(lv, "[data-role='correlation-summary']", "revenue")
        assert has_element?(lv, "[data-role='data-window']")
        assert has_element?(lv, "[data-role='data-points']")
      end)
    end
  end

  describe "switches between Raw and Smart modes on mode toggle click" do
    test "switches between Raw and Smart modes on mode toggle click", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(account.id)
      insert_correlation_result!(account.id, job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='raw-mode']")

        render_click(lv, "set_mode", %{"mode" => "smart"})
        assert has_element?(lv, "[data-role='smart-mode']")
        refute has_element?(lv, "[data-role='raw-mode']")

        render_click(lv, "set_mode", %{"mode" => "raw"})
        assert has_element?(lv, "[data-role='raw-mode']")
        refute has_element?(lv, "[data-role='smart-mode']")
      end)
    end
  end

  describe "sorts results table when column header is clicked" do
    test "sorts results table when column header is clicked", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(account.id)
      insert_correlation_result!(account.id, job, %{metric_name: "clicks", coefficient: 0.82})
      insert_correlation_result!(account.id, job, %{metric_name: "impressions", coefficient: 0.45})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "sort", %{"by" => "metric_name"})
        assert has_element?(lv, "[data-sort-col='metric_name'][data-sort-active='true']")

        render_click(lv, "sort", %{"by" => "coefficient"})
        assert has_element?(lv, "[data-sort-col='coefficient'][data-sort-active='true']")
      end)
    end
  end

  describe "filters results by platform when platform filter button is clicked" do
    test "filters results by platform when platform filter button is clicked", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(account.id)
      insert_correlation_result!(account.id, job, %{metric_name: "clicks", provider: :google_ads})
      insert_correlation_result!(account.id, job, %{metric_name: "spend", provider: :facebook_ads})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='filter-controls']")

        render_click(lv, "filter_platform", %{"platform" => "google_ads"})
        assert has_element?(lv, "[data-role='results-table']")

        render_click(lv, "filter_platform", %{"platform" => "all"})
        assert has_element?(lv, "[data-role='results-table']")
      end)
    end
  end

  describe "shows empty filter state when no results match selected platform" do
    test "shows empty filter state when no results match selected platform", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(account.id)
      insert_correlation_result!(account.id, job, %{metric_name: "clicks", provider: :google_ads})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "filter_platform", %{"platform" => "facebook_ads"})
        assert has_element?(lv, "[data-role='empty-filter-state']")
      end)
    end
  end

  describe "triggers correlation run and shows job running banner" do
    test "triggers correlation run and shows job running banner", %{conn: conn} do
      {user, account} = user_with_personal_account()
      insert_running_job!(account.id)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='job-running-banner']")
        assert has_element?(lv, "[data-role='run-correlations'][disabled]")
      end)
    end
  end

  describe "shows insufficient data warning when correlation run fails due to insufficient data" do
    test "shows insufficient data warning when correlation run fails due to insufficient data", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "run_correlations", %{})

        assert html =~ "Not enough data"
        assert has_element?(lv, "[data-role='insufficient-data-warning']")
      end)
    end
  end

  describe "shows Smart mode opt-in card before AI suggestions are enabled" do
    test "shows Smart mode opt-in card before AI suggestions are enabled", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "set_mode", %{"mode" => "smart"})

        assert has_element?(lv, "[data-role='smart-mode']")
        assert has_element?(lv, "[data-role='enable-ai-suggestions']")
      end)
    end
  end

  describe "enables AI suggestions and shows recommendations panel" do
    test "enables AI suggestions and shows recommendations panel", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "set_mode", %{"mode" => "smart"})
        render_click(lv, "enable_ai_suggestions", %{})

        assert has_element?(lv, "[data-role='ai-suggestions-enabled']")
        assert has_element?(lv, "[data-role='ai-recommendations']")
      end)
    end
  end

  describe "submits AI feedback and shows confirmation message" do
    test "submits AI feedback and shows confirmation message", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "set_mode", %{"mode" => "smart"})
        render_click(lv, "enable_ai_suggestions", %{})

        assert has_element?(lv, "[data-role='ai-feedback-section']")

        render_click(lv, "submit_smart_feedback", %{"rating" => "helpful"})

        assert has_element?(lv, "[data-role='feedback-confirmation']")
      end)
    end
  end
end
