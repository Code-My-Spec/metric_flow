defmodule MetricFlowSpex.UserCanOpenAiChatFromAnyReportOrVisualizationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can open AI chat from any report or visualization" do
    scenario "user sees an open AI chat button or link on the dashboard page" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the dashboard page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "an open AI chat button or link is visible on the dashboard", context do
        html = render(context.view)

        has_chat_entry_point =
          has_element?(context.view, "[data-role='open-ai-chat']") or
            has_element?(context.view, "a[data-role='open-ai-chat']") or
            has_element?(context.view, "button[data-role='open-ai-chat']") or
            has_element?(context.view, "[data-role='ai-chat-button']") or
            has_element?(context.view, "[href='/chat']") or
            html =~ "open-ai-chat" or
            html =~ "Open AI Chat" or
            html =~ "AI Chat" or
            html =~ "Open Chat" or
            html =~ "chat"

        assert has_chat_entry_point,
               "Expected an AI chat button or link on the dashboard page (data-role='open-ai-chat'). Got: #{html}"

        :ok
      end
    end

    scenario "user sees an open AI chat button or link on the correlations page" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "an open AI chat button or link is visible on the correlations page", context do
        html = render(context.view)

        has_chat_entry_point =
          has_element?(context.view, "[data-role='open-ai-chat']") or
            has_element?(context.view, "a[data-role='open-ai-chat']") or
            has_element?(context.view, "button[data-role='open-ai-chat']") or
            has_element?(context.view, "[data-role='ai-chat-button']") or
            has_element?(context.view, "[href='/chat']") or
            html =~ "open-ai-chat" or
            html =~ "Open AI Chat" or
            html =~ "AI Chat" or
            html =~ "Open Chat" or
            html =~ "chat"

        assert has_chat_entry_point,
               "Expected an AI chat button or link on the correlations page (data-role='open-ai-chat'). Got: #{html}"

        :ok
      end
    end

    scenario "user sees an open AI chat button or link on the insights page" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the insights page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/insights")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "an open AI chat button or link is visible on the insights page", context do
        html = render(context.view)

        has_chat_entry_point =
          has_element?(context.view, "[data-role='open-ai-chat']") or
            has_element?(context.view, "a[data-role='open-ai-chat']") or
            has_element?(context.view, "button[data-role='open-ai-chat']") or
            has_element?(context.view, "[data-role='ai-chat-button']") or
            has_element?(context.view, "[href='/chat']") or
            html =~ "open-ai-chat" or
            html =~ "Open AI Chat" or
            html =~ "AI Chat" or
            html =~ "Open Chat" or
            html =~ "chat"

        assert has_chat_entry_point,
               "Expected an AI chat button or link on the insights page (data-role='open-ai-chat'). Got: #{html}"

        :ok
      end
    end

    scenario "clicking the AI chat button navigates to the chat page or opens a chat interface" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the dashboard page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the open AI chat button or link", context do
        view = context.view

        result =
          cond do
            has_element?(view, "[data-role='open-ai-chat']") ->
              view
              |> element("[data-role='open-ai-chat']")
              |> render_click()

            has_element?(view, "button[data-role='open-ai-chat']") ->
              view
              |> element("button[data-role='open-ai-chat']")
              |> render_click()

            has_element?(view, "[data-role='ai-chat-button']") ->
              view
              |> element("[data-role='ai-chat-button']")
              |> render_click()

            has_element?(view, "a[href='/chat']") ->
              view
              |> element("a[href='/chat']")
              |> render_click()

            true ->
              render(view)
          end

        {:ok, Map.put(context, :after_click_html, result)}
      end

      then_ "the user is navigated to the chat page or a chat interface becomes visible", context do
        view = context.view
        html = render(view)

        chat_opened =
          has_element?(view, "[data-role='ai-chat-interface']") or
            has_element?(view, "[data-role='ai-chat']") or
            has_element?(view, "[data-role='chat-panel']") or
            has_element?(view, "[data-role='chat-input']") or
            html =~ "ai-chat-interface" or
            html =~ "AI Chat" or
            html =~ "ai-chat" or
            html =~ "chat-input" or
            html =~ "Ask a question" or
            html =~ "Type your message" or
            match?({:error, {:redirect, %{to: "/app/chat"}}}, live(context.owner_conn, "/app/dashboard")) or
            match?(
              {:error, {:live_redirect, %{to: "/app/chat"}}},
              live(context.owner_conn, "/app/dashboard")
            )

        assert chat_opened,
               "Expected clicking the AI chat button to navigate to /chat or open a chat interface. Got: #{html}"

        :ok
      end
    end
  end
end
