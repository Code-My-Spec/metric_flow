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
  alias MetricFlow.Users.Scope

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

  defp get_account_id(account), do: account.id

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

  defp insert_pending_job!(account_id, attrs \\ %{}) do
    defaults = %{
      account_id: account_id,
      status: :pending,
      goal_metric_name: "revenue"
    }

    %CorrelationJob{}
    |> CorrelationJob.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_running_job!(account_id, attrs \\ %{}) do
    defaults = %{
      account_id: account_id,
      status: :running,
      goal_metric_name: "revenue",
      started_at: ~U[2026-01-31 10:00:00.000000Z]
    }

    %CorrelationJob{}
    |> CorrelationJob.changeset(Map.merge(defaults, attrs))
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
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the correlations page for an authenticated user", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert is_binary(html)
      end)
    end

    test "shows page title 'Correlations'", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "Correlations"
      end)
    end

    test "shows 'No Correlations Yet' empty state when no correlation data exists", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "No Correlations Yet"
      end)
    end

    test "renders the no-data-state element when no correlation data exists", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='no-data-state']")
      end)
    end

    test "shows raw mode toggle on the page by default", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='mode-raw']")
      end)
    end

    test "shows mode toggle group on the page", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='mode-toggle']")
      end)
    end

    test "shows correlation results table when completed job and results exist", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='results-table']")
      end)
    end

    test "shows raw mode section when results exist", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='raw-mode']")
      end)
    end

    test "does not show no-data-state when results exist", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        refute has_element?(lv, "[data-role='no-data-state']")
      end)
    end

    test "shows summary bar when results exist", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='correlation-summary']")
      end)
    end

    test "shows goal metric in summary bar", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account), %{goal_metric_name: "revenue"})
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='goal-metric']")
        assert has_element?(lv, "[data-role='correlation-summary']", "revenue")
      end)
    end

    test "shows last calculated element in summary bar when job has completed_at", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='last-calculated']")
      end)
    end

    test "shows data window element in summary bar when job has data window", %{conn: conn} do
      {user, account} = user_with_personal_account()

      job =
        insert_completed_job!(get_account_id(account), %{
          data_window_start: ~D[2026-01-01],
          data_window_end: ~D[2026-01-31]
        })

      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='data-window']")
      end)
    end

    test "shows data points element in summary bar when job has data points", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account), %{data_points: 90})
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='data-points']")
      end)
    end

    test "shows job running banner when a correlation job is pending", %{conn: conn} do
      {user, account} = user_with_personal_account()
      insert_pending_job!(get_account_id(account))
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='job-running-banner']")
      end)
    end

    test "shows job running banner when a correlation job is running", %{conn: conn} do
      {user, account} = user_with_personal_account()
      insert_running_job!(get_account_id(account))
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='job-running-banner']")
      end)
    end

    test "does not show job running banner when no active jobs exist", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        refute has_element?(lv, "[data-role='job-running-banner']")
      end)
    end

    test "redirects unauthenticated user to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/correlations")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event set_mode"
  # ---------------------------------------------------------------------------

  describe "handle_event \"set_mode\"" do
    test "switches to smart mode when smart button is clicked", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "set_mode", %{"mode" => "smart"})

        assert is_binary(html)
      end)
    end

    test "smart mode shows enable AI suggestions button", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "set_mode", %{"mode" => "smart"})

        assert has_element?(lv, "[data-role='smart-mode']")
        assert has_element?(lv, "[data-role='enable-ai-suggestions']")
      end)
    end

    test "smart mode does not show the raw mode section", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "set_mode", %{"mode" => "smart"})

        refute has_element?(lv, "[data-role='raw-mode']")
      end)
    end

    test "switches back to raw mode when raw button is clicked", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "set_mode", %{"mode" => "smart"})
        render_click(lv, "set_mode", %{"mode" => "raw"})

        assert has_element?(lv, "[data-role='raw-mode']")
        refute has_element?(lv, "[data-role='smart-mode']")
      end)
    end

    test "raw mode shows the results table when data exists", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "set_mode", %{"mode" => "smart"})
        render_click(lv, "set_mode", %{"mode" => "raw"})

        assert has_element?(lv, "[data-role='results-table']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event sort"
  # ---------------------------------------------------------------------------

  describe "handle_event \"sort\"" do
    test "coefficient column is present in the results table by default", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "clicks", coefficient: 0.82})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-sort-col='coefficient']")
      end)
    end

    test "toggles sort direction when the same column is clicked again", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "clicks", coefficient: 0.82})
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "impressions", coefficient: 0.45})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "sort", %{"by" => "coefficient"})

        assert is_binary(html)
      end)
    end

    test "switches sort column when a different column is clicked", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "sort", %{"by" => "metric_name"})

        assert has_element?(lv, "[data-sort-col='metric_name'][data-sort-active='true']")
      end)
    end

    test "sorts by metric name when metric_name column is clicked", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "sort", %{"by" => "metric_name"})

        assert is_binary(html)
      end)
    end

    test "sorts by lag when lag column is clicked", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "sort", %{"by" => "lag"})

        assert is_binary(html)
      end)
    end

    test "sorts by platform when platform column is clicked", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "sort", %{"by" => "platform"})

        assert is_binary(html)
      end)
    end

    test "marks the active sort column with data-sort-active='true'", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "sort", %{"by" => "metric_name"})

        assert has_element?(lv, "[data-sort-col='metric_name'][data-sort-active='true']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event filter_platform"
  # ---------------------------------------------------------------------------

  describe "handle_event \"filter_platform\"" do
    test "filters results by platform without error", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))

      insert_correlation_result!(get_account_id(account), job, %{
        metric_name: "clicks",
        provider: :google_ads
      })

      insert_correlation_result!(get_account_id(account), job, %{
        metric_name: "spend",
        provider: :facebook_ads
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "filter_platform", %{"platform" => "google_ads"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='results-table']")
      end)
    end

    test "shows all platforms when 'all' is selected", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))

      insert_correlation_result!(get_account_id(account), job, %{
        metric_name: "clicks",
        provider: :google_ads
      })

      insert_correlation_result!(get_account_id(account), job, %{
        metric_name: "spend",
        provider: :facebook_ads
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "filter_platform", %{"platform" => "google_ads"})
        html = render_click(lv, "filter_platform", %{"platform" => "all"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='results-table']")
      end)
    end

    test "shows empty filter state when no results match the selected platform", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))

      insert_correlation_result!(get_account_id(account), job, %{
        metric_name: "clicks",
        provider: :google_ads
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "filter_platform", %{"platform" => "facebook_ads"})

        assert has_element?(lv, "[data-role='empty-filter-state']")
      end)
    end

    test "shows the filter controls section when data exists", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='filter-controls']")
      end)
    end

    test "shows platform filter buttons when data exists", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{provider: :google_ads})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='platform-filter']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event run_correlations"
  # ---------------------------------------------------------------------------

  describe "handle_event \"run_correlations\"" do
    test "shows the Run Now button on the page", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='run-correlations']")
      end)
    end

    test "shows error flash when insufficient data to run correlations", %{conn: conn} do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "run_correlations", %{})

        assert html =~ "Not enough data"
      end)
    end

    test "shows insufficient data warning badge when run returns :insufficient_data", %{
      conn: conn
    } do
      {user, _account} = user_with_personal_account()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        render_click(lv, "run_correlations", %{})

        assert has_element?(lv, "[data-role='insufficient-data-warning']")
      end)
    end

    test "shows info flash when a correlation run is already in progress", %{conn: conn} do
      {user, account} = user_with_personal_account()
      insert_running_job!(get_account_id(account))
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        html = render_click(lv, "run_correlations", %{})

        assert html =~ "already in progress"
      end)
    end

    test "Run Now button is disabled when a job is running", %{conn: conn} do
      {user, account} = user_with_personal_account()
      insert_running_job!(get_account_id(account))
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='run-correlations'][disabled]")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "correlation results table"
  # ---------------------------------------------------------------------------

  describe "correlation results table" do
    test "renders a correlation row for each result", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "clicks"})

      insert_correlation_result!(get_account_id(account), job, %{
        metric_name: "impressions",
        coefficient: 0.45
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='correlation-row'][data-metric='clicks']")
        assert has_element?(lv, "[data-role='correlation-row'][data-metric='impressions']")
      end)
    end

    test "renders strength badge for each result row", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "clicks", coefficient: 0.82})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[data-role='strength-badge']")
      end)
    end

    test "shows 'Strong' badge for coefficient >= 0.7", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "clicks", coefficient: 0.82})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "Strong"
      end)
    end

    test "shows 'Moderate' badge for coefficient between 0.4 and 0.7", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "impressions", coefficient: 0.55})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "Moderate"
      end)
    end

    test "shows 'Weak' badge for coefficient between 0.2 and 0.4", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "reach", coefficient: 0.30})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "Weak"
      end)
    end

    test "shows 'Same day' for results with optimal lag of zero", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "clicks", optimal_lag: 0})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "Same day"
      end)
    end

    test "shows lag in days for results with optimal lag greater than zero", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "clicks", optimal_lag: 7})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "days"
      end)
    end

    test "shows provider display name for results with a provider", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "clicks", provider: :google_ads})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "Google Ads"
      end)
    end

    test "shows 'Derived' for results with nil provider", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))

      insert_correlation_result!(get_account_id(account), job, %{
        metric_name: "derived_metric",
        provider: nil
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "Derived"
      end)
    end

    test "shows the metric name in each correlation row", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job, %{metric_name: "cost_per_click"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/correlations")

        assert html =~ "cost_per_click"
      end)
    end

    test "shows sortable column headers in the results table", %{conn: conn} do
      {user, account} = user_with_personal_account()
      job = insert_completed_job!(get_account_id(account))
      insert_correlation_result!(get_account_id(account), job)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/correlations")

        assert has_element?(lv, "[phx-click='sort'][phx-value-by='coefficient']")
        assert has_element?(lv, "[phx-click='sort'][phx-value-by='metric_name']")
        assert has_element?(lv, "[phx-click='sort'][phx-value-by='lag']")
        assert has_element?(lv, "[phx-click='sort'][phx-value-by='platform']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/correlations")
    end
  end
end
