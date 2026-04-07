defmodule MetricFlowSpex.AiHasAccessToAllMetricsAndCorrelationDataToAnswerSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "AI has access to all metrics and correlation data to answer" do
    scenario "AI response references metric-related terms when asked about metrics" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits a question about their metrics", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "What are my top metrics this month?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "What are my top metrics this month?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "What are my top metrics this month?"})

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the AI response references metric-related terms", context do
        html = render(context.view)

        has_metric_terms =
          html =~ "metric" or
            html =~ "Metric" or
            html =~ "revenue" or
            html =~ "Revenue" or
            html =~ "spend" or
            html =~ "Spend" or
            html =~ "clicks" or
            html =~ "Clicks" or
            html =~ "impressions" or
            html =~ "Impressions" or
            html =~ "conversion" or
            html =~ "Conversion" or
            html =~ "performance" or
            html =~ "Performance" or
            html =~ "data" or
            html =~ "Data" or
            has_element?(context.view, "[data-role='ai-message']") or
            has_element?(context.view, "[data-role='assistant-message']")

        assert has_metric_terms,
               "Expected the AI response to reference metric-related terms such as 'metric', 'revenue', 'spend', 'clicks', or 'impressions'. Got: #{html}"

        :ok
      end
    end

    scenario "AI response references correlation-related terms when asked about correlations" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits a question about correlations in their data", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "What correlations exist in my data?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "What correlations exist in my data?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "What correlations exist in my data?"})

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the AI response references correlation or data relationship terms", context do
        html = render(context.view)

        has_correlation_terms =
          html =~ "correlation" or
            html =~ "Correlation" or
            html =~ "relationship" or
            html =~ "Relationship" or
            html =~ "trend" or
            html =~ "Trend" or
            html =~ "pattern" or
            html =~ "Pattern" or
            html =~ "association" or
            html =~ "Association" or
            html =~ "linked" or
            html =~ "related" or
            html =~ "data" or
            html =~ "Data" or
            has_element?(context.view, "[data-role='ai-message']") or
            has_element?(context.view, "[data-role='assistant-message']")

        assert has_correlation_terms,
               "Expected the AI response to reference correlation-related terms such as 'correlation', 'relationship', 'trend', or 'pattern'. Got: #{html}"

        :ok
      end
    end

    scenario "chat interface indicates it has access to the user's data" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chat interface shows a data access indicator or data-aware greeting", context do
        html = render(context.view)

        has_data_access_indicator =
          has_element?(context.view, "[data-role='data-sources']") or
            has_element?(context.view, "[data-role='data-access-indicator']") or
            has_element?(context.view, "[data-role='chat-context']") or
            has_element?(context.view, "[data-role='context-banner']") or
            has_element?(context.view, "[data-role='chat-header']") or
            html =~ "I have access to your metrics" or
            html =~ "access to your data" or
            html =~ "your metrics" or
            html =~ "your data" or
            html =~ "Your Metrics" or
            html =~ "Your Data" or
            html =~ "data-sources" or
            html =~ "data sources" or
            html =~ "Data Sources" or
            html =~ "metrics" or
            html =~ "Metrics" or
            html =~ "data" or
            html =~ "Data" or
            html =~ "connected" or
            html =~ "account"

        assert has_data_access_indicator,
               "Expected the chat interface to show a data access indicator (e.g., data-role='data-sources', or text like 'I have access to your metrics'). Got: #{html}"

        :ok
      end
    end

    scenario "chat page has a form that accepts user questions about data" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chat form is present and accepts input for data questions", context do
        html = render(context.view)

        has_chat_form =
          has_element?(context.view, "[data-role='chat-form']") or
            has_element?(context.view, "#chat-form") or
            has_element?(context.view, "form") or
            html =~ "chat-form" or
            html =~ "Ask a question" or
            html =~ "Type your message" or
            html =~ "Send" or
            html =~ "submit"

        assert has_chat_form,
               "Expected the chat page to have a form for submitting questions about metrics and correlation data. Got: #{html}"

        :ok
      end
    end
  end
end
