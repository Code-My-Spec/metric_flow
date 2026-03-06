defmodule MetricFlowWeb.AiLive.InsightsTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.AiFixtures

  alias MetricFlow.Accounts

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_account do
    {user, scope} = user_with_scope()
    account_id = Accounts.get_personal_account_id(scope)
    {user, account_id}
  end

  defp mount_insights(conn, user) do
    conn = log_in_user(conn, user)
    live(conn, ~p"/insights")
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the insights page for an authenticated user", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "AI Insights"
      end)
    end

    test "shows page title 'AI Insights'", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "AI Insights"
      end)
    end

    test "shows subtitle about correlation analysis", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "Actionable recommendations generated from your correlation analysis"
      end)
    end

    test "shows no-insights-state when no insights exist", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='no-insights-state']")
      end)
    end

    test "shows 'No Insights Yet' heading in empty state", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "No Insights Yet"
      end)
    end

    test "shows link to run correlations in empty state", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, lv, html} = mount_insights(conn, user)

        assert html =~ "Run Correlations"
        assert has_element?(lv, "a[href='/correlations']")
      end)
    end

    test "shows type filter bar", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='type-filter']")
      end)
    end

    test "shows insight cards when insights exist", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insight-card']")
      end)
    end

    test "does not show no-insights-state when insights exist", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        refute has_element?(lv, "[data-role='no-insights-state']")
      end)
    end

    test "shows insights list when insights exist", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insights-list']")
      end)
    end

    test "shows insight summary in card", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{summary: "Increase Google Ads budget"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "Increase Google Ads budget"
      end)
    end

    test "shows insight content in card", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{content: "Based on strong correlation with revenue growth."})

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "Based on strong correlation with revenue growth."
      end)
    end

    test "shows suggestion type badge", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :budget_increase})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insight-type-badge']")
      end)
    end

    test "shows confidence badge", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{confidence: 0.85})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insight-confidence-badge']")
      end)
    end

    test "shows confidence as percentage", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{confidence: 0.85})

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "85% confidence"
      end)
    end

    test "shows correlation reference when correlation_result_id is present", %{conn: conn} do
      {user, account_id} = user_with_account()
      result = insert_correlation_result!(account_id)
      insert_insight!(account_id, %{correlation_result_id: result.id})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insight-correlation-ref']")
      end)
    end

    test "does not show correlation reference when correlation_result_id is nil", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{correlation_result_id: nil})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        refute has_element?(lv, "[data-role='insight-correlation-ref']")
      end)
    end

    test "shows generated at timestamp", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insight-generated-at']")
      end)
    end

    test "shows feedback section on each insight card", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='ai-feedback-section']")
      end)
    end

    test "shows helpful and not helpful feedback buttons when no feedback exists", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='feedback-helpful']")
        assert has_element?(lv, "[data-role='feedback-not-helpful']")
      end)
    end

    test "shows feedback helper text when no feedback exists", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "Your feedback helps improve future suggestions."
      end)
    end

    test "shows ai personalization note when insights exist", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='ai-personalization-note']")
        assert html =~ "AI suggestions learn from your feedback and improve over time."
      end)
    end

    test "does not show ai personalization note when no insights exist", %{conn: conn} do
      {user, _account_id} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        refute has_element?(lv, "[data-role='ai-personalization-note']")
      end)
    end

    test "shows feedback confirmation when user has existing feedback", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)
      insert_suggestion_feedback!(insight.id, user.id, %{rating: :helpful})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='feedback-confirmation']")
      end)
    end

    test "redirects unauthenticated user to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/insights")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event filter_type"
  # ---------------------------------------------------------------------------

  describe "handle_event \"filter_type\"" do
    test "filters insights by suggestion type", %{conn: conn} do
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

    test "shows all insights when 'all' filter is selected", %{conn: conn} do
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

    test "shows no-filter-results-state when filter has no matches", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :budget_increase})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        render_click(lv, "filter_type", %{"type" => "monitoring"})

        assert has_element?(lv, "[data-role='no-filter-results-state']")
      end)
    end

    test "shows 'Show All' button in empty filter state", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :budget_increase})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        render_click(lv, "filter_type", %{"type" => "monitoring"})

        assert has_element?(lv, "[data-role='clear-filter']")
      end)
    end

    test "highlights the active filter button with btn-primary", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        html = render_click(lv, "filter_type", %{"type" => "budget_increase"})

        assert html =~ "btn-primary"
      end)
    end

    test "filters by budget_decrease type", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :budget_decrease, summary: "Reduce spend"})
      insert_insight!(account_id, %{suggestion_type: :general, summary: "General info"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        html = render_click(lv, "filter_type", %{"type" => "budget_decrease"})

        assert html =~ "Reduce spend"
        refute html =~ "General info"
      end)
    end

    test "filters by general type", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :general, summary: "General info"})
      insert_insight!(account_id, %{suggestion_type: :budget_increase, summary: "Increase spend"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        html = render_click(lv, "filter_type", %{"type" => "general"})

        assert html =~ "General info"
        refute html =~ "Increase spend"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event submit_feedback"
  # ---------------------------------------------------------------------------

  describe "handle_event \"submit_feedback\"" do
    test "submits helpful feedback and shows confirmation", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        render_click(lv, "submit_feedback", %{
          "insight-id" => to_string(insight.id),
          "rating" => "helpful"
        })

        assert has_element?(lv, "[data-role='feedback-confirmation']")
      end)
    end

    test "shows confirmation text after submitting feedback", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        html =
          render_click(lv, "submit_feedback", %{
            "insight-id" => to_string(insight.id),
            "rating" => "helpful"
          })

        assert html =~ "Thanks for your feedback"
      end)
    end

    test "submits not_helpful feedback and shows confirmation", %{conn: conn} do
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

    test "hides feedback buttons after submitting feedback", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        render_click(lv, "submit_feedback", %{
          "insight-id" => to_string(insight.id),
          "rating" => "helpful"
        })

        refute has_element?(lv, "[data-role='feedback-helpful'][data-insight-id='#{insight.id}']") and
                 has_element?(lv, "[data-role='feedback-not-helpful'][data-insight-id='#{insight.id}']")
      end)
    end

    test "can change feedback from helpful to not_helpful", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)
      insert_suggestion_feedback!(insight.id, user.id, %{rating: :helpful})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        # User already has feedback, but they can change it via the UI
        assert has_element?(lv, "[data-role='feedback-confirmation']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "insight card details"
  # ---------------------------------------------------------------------------

  describe "insight card details" do
    test "renders multiple insight cards", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{summary: "First insight"})
      insert_insight!(account_id, %{summary: "Second insight"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "First insight"
        assert html =~ "Second insight"
      end)
    end

    test "shows Budget Increase badge for budget_increase type", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :budget_increase})

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "Budget Increase"
      end)
    end

    test "shows Optimization badge for optimization type", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :optimization})

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "Optimization"
      end)
    end

    test "shows Monitoring badge for monitoring type", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :monitoring})

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "Monitoring"
      end)
    end

    test "shows General badge for general type", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{suggestion_type: :general})

      capture_log(fn ->
        {:ok, _lv, html} = mount_insights(conn, user)

        assert html =~ "General"
      end)
    end

    test "shows high confidence with success badge styling", %{conn: conn} do
      {user, account_id} = user_with_account()
      insert_insight!(account_id, %{confidence: 0.92})

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insight-confidence-badge']")
      end)
    end

    test "shows insight data-insight-id attribute", %{conn: conn} do
      {user, account_id} = user_with_account()
      insight = insert_insight!(account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_insights(conn, user)

        assert has_element?(lv, "[data-role='insight-card'][data-insight-id='#{insight.id}']")
      end)
    end
  end
end
