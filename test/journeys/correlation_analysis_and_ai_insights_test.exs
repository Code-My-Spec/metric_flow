defmodule MetricFlowWeb.Journeys.CorrelationAnalysisAndAiInsightsTest do
  @moduledoc """
  Journey 4 from `.code_my_spec/qa/journey_plan.md`: a subscribed owner picks
  a goal metric, sees the correlations page, and can reach the AI insights,
  chat, and report generator screens.
  """

  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.BillingFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp user_with_subscribed_account do
    user = user_fixture()

    {:ok, account} =
      %Account{}
      |> Account.creation_changeset(%{
        name: "QA Journey4 Account",
        slug: unique_slug(),
        type: "client",
        originator_user_id: user.id
      })
      |> Repo.insert()

    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: :owner})
    |> Repo.insert!()

    # Every screen in this journey sits behind `RequireSubscriptionHook`.
    active_subscription_fixture(account.id)

    {user, account}
  end

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

  test "selects a goal metric, reaches correlations, and the AI pages all render", %{conn: conn} do
    {user, _account} = user_with_subscribed_account()
    insert_sufficient_metrics!(user)
    conn = log_in_user(conn, user)

    capture_log(fn ->
      # Step 2-4: goal metric selection
      {:ok, lv, _html} = live(conn, ~p"/app/correlations/goals")
      render_change(lv, "select_goal", %{"goal_metric_name" => "revenue"})
      lv |> form("#goal-metric-form") |> render_submit()

      flash = assert_redirect(lv, ~p"/app/correlations")
      assert flash["info"] =~ "Correlation analysis started"

      # Step 5-8: correlations page renders with Raw/Smart mode toggle
      {:ok, _lv, corr_html} = live(conn, ~p"/app/correlations")
      assert corr_html =~ "Correlations"
      assert corr_html =~ "Raw"
      assert corr_html =~ "Smart"

      # Step 9-10: AI insights page renders
      {:ok, _lv, insights_html} = live(conn, ~p"/app/insights")
      assert insights_html =~ "AI Insights"

      # Step 11: AI chat page renders with session sidebar
      {:ok, _lv, chat_html} = live(conn, ~p"/app/chat")
      assert chat_html =~ "AI Chat"

      # Step 14: natural language report generator renders
      {:ok, _lv, report_html} = live(conn, ~p"/app/reports/generate")
      assert report_html =~ "Generate Report"
    end)
  end
end
