defmodule MetricFlowWeb.AiLive.InsightsTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.AiFixtures
  import MetricFlowTest.BillingFixtures

  alias MetricFlow.Accounts

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_account do
    {user, scope} = user_with_scope()
    account_id = Accounts.get_personal_account_id(scope)
    # Every screen these tests mount sits behind `RequireSubscriptionHook`, which
    # redirects to checkout without one.
    active_subscription_fixture(account_id)
    {user, account_id}
  end

  defp mount_insights(conn, user) do
    conn = log_in_user(conn, user)
    live(conn, ~p"/app/insights")
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders insights page with header and type filter bar" do
    test "renders insights page with header and type filter bar", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, lv, html} = mount_insights(conn, user)

        assert html =~ "AI Insights"
        assert html =~ "Newest first"
        assert has_element?(lv, "[data-role='type-filter']")
      end)
    end
  end

  describe "shows no-insights empty state when account has no insights" do
    test "shows no-insights empty state when account has no insights", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, lv, html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='no-insights-state']")
        assert html =~ "No Insights Yet"
        assert has_element?(lv, "a[href='/app/correlations']")
      end)
    end
  end

  describe "displays insight cards with summary, type badge, confidence badge, and content" do
    test "displays insight cards with summary, type badge, confidence badge, and content", %{
      conn: conn
    } do
      {user, account_id} = user_with_account()

      insert_insight!(account_id, %{
        summary: "Increase Google Ads budget",
        content: "Based on strong correlation with revenue growth.",
        suggestion_type: :budget_increase,
        confidence: 0.85
      })

      capture_log(fn ->
        {:ok, lv, html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insight-card']")
        assert html =~ "Increase Google Ads budget"
        assert html =~ "Based on strong correlation with revenue growth."
        assert has_element?(lv, "[data-role='insight-type-badge']")
        assert has_element?(lv, "[data-role='insight-confidence-badge']")
        assert html =~ "85% confidence"
        refute has_element?(lv, "[data-role='no-insights-state']")
      end)
    end
  end

  describe "filters insights by type when filter button is clicked" do
    test "filters insights by type when filter button is clicked", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :budget_increase, summary: "Increase spend"})

      insert_insight!(account_id, %{suggestion_type: :optimization, summary: "Optimize targeting"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        html = render_click(lv, "filter_type", %{"type" => "budget_increase"})

        assert html =~ "Increase spend"
        refute html =~ "Optimize targeting"
      end)
    end
  end

  describe "highlights active filter button with btn-primary" do
    test "highlights active filter button with btn-primary", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        html = render_click(lv, "filter_type", %{"type" => "budget_increase"})

        assert html =~ "btn-primary"
      end)
    end
  end

  describe "shows empty filter state when no insights match selected type" do
    test "shows empty filter state when no insights match selected type", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :budget_increase})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        render_click(lv, "filter_type", %{"type" => "monitoring"})

        assert has_element?(lv, "[data-role='no-filter-results-state']")
      end)
    end
  end

  describe "clears filter and shows all insights when Show All is clicked" do
    test "clears filter and shows all insights when Show All is clicked", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :budget_increase, summary: "Increase spend"})

      insert_insight!(account_id, %{suggestion_type: :optimization, summary: "Optimize targeting"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        render_click(lv, "filter_type", %{"type" => "budget_increase"})
        html = render_click(lv, "filter_type", %{"type" => "all"})

        assert html =~ "Increase spend"
        assert html =~ "Optimize targeting"
      end)
    end
  end

  describe "submits helpful feedback and shows confirmation message" do
    test "submits helpful feedback and shows confirmation message", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        html =
          render_click(lv, "submit_feedback", %{
            "insight-id" => to_string(insight.id),
            "rating" => "helpful"
          })

        assert has_element?(lv, "[data-role='feedback-confirmation']")
        assert html =~ "Thanks for your feedback"
      end)
    end
  end

  describe "submits not helpful feedback and shows confirmation message" do
    test "submits not helpful feedback and shows confirmation message", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        render_click(lv, "submit_feedback", %{
          "insight-id" => to_string(insight.id),
          "rating" => "not_helpful"
        })

        assert has_element?(lv, "[data-role='feedback-confirmation']")
      end)
    end
  end

  describe "shows feedback confirmation for insights that already have feedback" do
    test "shows feedback confirmation for insights that already have feedback", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)
      insert_suggestion_feedback!(insight.id, user.id, %{rating: :helpful})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='feedback-confirmation']")
      end)
    end
  end

  describe "shows AI personalization note when insights exist" do
    test "shows AI personalization note when insights exist", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='ai-personalization-note']")
        assert html =~ "AI suggestions learn from your feedback and improve over time."
      end)
    end
  end

  describe "marks each insight as verified or hypothesis" do
    test "labels a high-confidence insight as Verified", %{conn: conn} do
      {user, account_id} = user_with_account()

      insert_insight!(account_id, %{
        summary: "Increase Google Ads budget",
        confidence: 0.85
      })

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(
                 lv,
                 "[data-role='insight-status-badge'][data-insight-status='verified']",
                 "Verified"
               )

        refute has_element?(
                 lv,
                 "[data-role='insight-status-badge'][data-insight-status='hypothesis']"
               )
      end)
    end

    test "labels a low-confidence insight as Hypothesis", %{conn: conn} do
      {user, account_id} = user_with_account()

      insert_insight!(account_id, %{
        summary: "Watch TikTok Ads spend",
        confidence: 0.4
      })

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(
                 lv,
                 "[data-role='insight-status-badge'][data-insight-status='hypothesis']",
                 "Hypothesis"
               )

        refute has_element?(
                 lv,
                 "[data-role='insight-status-badge'][data-insight-status='verified']"
               )
      end)
    end

    test "lists insights newest first", %{conn: conn} do
      {user, account_id} = user_with_account()
      now = DateTime.utc_now()

      insert_insight!(account_id, %{
        summary: "Older recommendation",
        generated_at: DateTime.add(now, -3600, :second)
      })

      insert_insight!(account_id, %{
        summary: "Newer recommendation",
        generated_at: now
      })

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        newer_index = :binary.match(html, "Newer recommendation") |> elem(0)
        older_index = :binary.match(html, "Older recommendation") |> elem(0)
        assert newer_index < older_index
      end)
    end
  end
end
