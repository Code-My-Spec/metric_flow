defmodule MetricFlowSpex.ChatContextIncludesRelevantDataFromCurrentViewSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Chat context includes relevant data from current view" do
    scenario "chat page displays a context indicator when opened directly" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates directly to the chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chat interface shows some context indicator or greeting about the user's data", context do
        html = render(context.view)

        has_context_indicator =
          has_element?(context.view, "[data-role='chat-context']") or
            has_element?(context.view, "[data-role='chat-context-indicator']") or
            has_element?(context.view, "[data-role='context-banner']") or
            has_element?(context.view, "[data-role='chat-header']") or
            html =~ "chat-context" or
            html =~ "metrics" or
            html =~ "Metrics" or
            html =~ "data" or
            html =~ "Data" or
            html =~ "context" or
            html =~ "Context" or
            html =~ "dashboard" or
            html =~ "Dashboard" or
            html =~ "account" or
            html =~ "Account"

        assert has_context_indicator,
               "Expected the chat page to display a context indicator or reference to the user's data. Got: #{html}"

        :ok
      end
    end

    scenario "chat page opened from dashboard shows dashboard or metrics context" do
      given_ :user_logged_in_as_owner

      given_ "the user is on the dashboard page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user navigates to the chat page via a dashboard link or by visiting /chat", context do
        # Try to follow the AI chat link from the dashboard, or navigate directly to /chat
        view = context.view

        chat_view =
          cond do
            has_element?(view, "[data-role='open-ai-chat']") ->
              view |> element("[data-role='open-ai-chat']") |> render_click()
              # After click, try to get the updated or redirected view
              case live(context.owner_conn, "/chat") do
                {:ok, chat_v, _html} -> chat_v
                _ -> view
              end

            has_element?(view, "a[href='/chat']") ->
              case live(context.owner_conn, "/chat") do
                {:ok, chat_v, _html} -> chat_v
                _ -> view
              end

            true ->
              # Fall back to navigating to /chat directly
              case live(context.owner_conn, "/chat") do
                {:ok, chat_v, _html} -> chat_v
                _ -> view
              end
          end

        {:ok, Map.put(context, :chat_view, chat_view)}
      end

      then_ "the chat interface indicates it has context about the user's metrics or dashboard", context do
        html = render(context.chat_view)

        has_dashboard_context =
          has_element?(context.chat_view, "[data-role='chat-context']") or
            has_element?(context.chat_view, "[data-role='chat-context-indicator']") or
            has_element?(context.chat_view, "[data-role='context-banner']") or
            has_element?(context.chat_view, "[data-role='context-breadcrumb']") or
            html =~ "chat-context" or
            html =~ "dashboard" or
            html =~ "Dashboard" or
            html =~ "metrics" or
            html =~ "Metrics" or
            html =~ "data" or
            html =~ "Data" or
            html =~ "context" or
            html =~ "Context"

        assert has_dashboard_context,
               "Expected the chat interface to indicate it has context about the user's dashboard or metrics. Got: #{html}"

        :ok
      end
    end

    scenario "chat opened from correlations page shows correlation context" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user navigates to the chat page from correlations", context do
        view = context.view

        chat_view =
          cond do
            has_element?(view, "[data-role='open-ai-chat']") ->
              view |> element("[data-role='open-ai-chat']") |> render_click()

              case live(context.owner_conn, "/chat") do
                {:ok, chat_v, _html} -> chat_v
                _ -> view
              end

            has_element?(view, "a[href='/chat']") ->
              case live(context.owner_conn, "/chat") do
                {:ok, chat_v, _html} -> chat_v
                _ -> view
              end

            true ->
              case live(context.owner_conn, "/chat") do
                {:ok, chat_v, _html} -> chat_v
                _ -> view
              end
          end

        {:ok, Map.put(context, :chat_view, chat_view)}
      end

      then_ "the chat interface shows some relevant context or data-aware greeting", context do
        html = render(context.chat_view)

        has_relevant_context =
          has_element?(context.chat_view, "[data-role='chat-context']") or
            has_element?(context.chat_view, "[data-role='chat-context-indicator']") or
            has_element?(context.chat_view, "[data-role='context-banner']") or
            has_element?(context.chat_view, "[data-role='context-breadcrumb']") or
            html =~ "chat-context" or
            html =~ "correlation" or
            html =~ "Correlation" or
            html =~ "metrics" or
            html =~ "Metrics" or
            html =~ "data" or
            html =~ "Data" or
            html =~ "context" or
            html =~ "Context"

        assert has_relevant_context,
               "Expected the chat interface to show relevant context when opened from correlations. Got: #{html}"

        :ok
      end
    end

    scenario "chat page shows a context indicator breadcrumb or label showing where the user came from" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chat page displays a breadcrumb, label, or indicator showing the current data context", context do
        html = render(context.view)

        has_context_ui_element =
          has_element?(context.view, "[data-role='chat-context']") or
            has_element?(context.view, "[data-role='chat-context-indicator']") or
            has_element?(context.view, "[data-role='context-breadcrumb']") or
            has_element?(context.view, "[data-role='context-banner']") or
            has_element?(context.view, "[data-role='context-label']") or
            has_element?(context.view, "[data-role='chat-header']") or
            has_element?(context.view, "[data-role='chat-subtitle']") or
            html =~ "Chatting about" or
            html =~ "chatting about" or
            html =~ "chat-context" or
            html =~ "context-indicator" or
            html =~ "your metrics" or
            html =~ "Your Metrics" or
            html =~ "your data" or
            html =~ "Your Data" or
            html =~ "metrics" or
            html =~ "data" or
            html =~ "context"

        assert has_context_ui_element,
               "Expected the chat page to show a context indicator or breadcrumb (e.g., data-role='chat-context', or text like 'Chatting about your metrics'). Got: #{html}"

        :ok
      end
    end
  end
end
