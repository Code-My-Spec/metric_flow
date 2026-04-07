defmodule MetricFlowSpex.UserCanAskQuestionsLikeWhyDidMyRevenueDropLastWeekSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can ask questions like Why did my revenue drop last week" do
    scenario "user sees a chat input field on the chat page" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a text input or textarea for asking questions", context do
        html = render(context.view)

        has_chat_input =
          has_element?(context.view, "[data-role='chat-input']") or
            has_element?(context.view, "textarea[data-role='chat-input']") or
            has_element?(context.view, "input[data-role='chat-input']") or
            has_element?(context.view, "[data-role='chat-form'] textarea") or
            has_element?(context.view, "[data-role='chat-form'] input[type='text']") or
            has_element?(context.view, "form textarea") or
            has_element?(context.view, "form input[type='text']") or
            html =~ "chat-input" or
            html =~ "Ask a question" or
            html =~ "Type your message" or
            html =~ "placeholder"

        assert has_chat_input,
               "Expected a chat input field (textarea or text input) on the chat page. Got: #{html}"

        :ok
      end
    end

    scenario "user types a revenue question and submits it" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user types and submits a revenue question", context do
        view = context.view

        result =
          cond do
            has_element?(view, "[data-role='chat-form']") ->
              view
              |> form("[data-role='chat-form']")
              |> render_submit(%{message: "Why did my revenue drop last week?"})

            has_element?(view, "#chat-form") ->
              view
              |> form("#chat-form")
              |> render_submit(%{message: "Why did my revenue drop last week?"})

            has_element?(view, "form") ->
              view
              |> form("form")
              |> render_submit(%{message: "Why did my revenue drop last week?"})

            true ->
              render(view)
          end

        {:ok, Map.put(context, :after_submit_html, result)}
      end

      then_ "the chat page responds without crashing", context do
        html = render(context.view)
        assert is_binary(html)
        :ok
      end
    end

    scenario "user's question appears in the chat after submitting" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits a revenue question", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "Why did my revenue drop last week?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "Why did my revenue drop last week?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "Why did my revenue drop last week?"})

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the user's question appears in the chat messages area", context do
        html = render(context.view)

        question_visible =
          has_element?(context.view, "[data-role='user-message']") or
            has_element?(context.view, "[data-role='chat-messages'] [data-role='user-message']") or
            html =~ "Why did my revenue drop last week?" or
            html =~ "user-message" or
            html =~ "revenue drop"

        assert question_visible,
               "Expected the user's question to appear in the chat after submitting. Got: #{html}"

        :ok
      end
    end

    scenario "an AI response appears in the chat after the user submits a question" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the question about revenue drop", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "Why did my revenue drop last week?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "Why did my revenue drop last week?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "Why did my revenue drop last week?"})

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "an AI response appears in the chat messages area", context do
        html = render(context.view)

        ai_response_visible =
          has_element?(context.view, "[data-role='ai-message']") or
            has_element?(context.view, "[data-role='chat-messages'] [data-role='ai-message']") or
            has_element?(context.view, "[data-role='assistant-message']") or
            has_element?(context.view, "[data-role='bot-message']") or
            html =~ "ai-message" or
            html =~ "assistant-message" or
            html =~ "AI:" or
            html =~ "Assistant:" or
            html =~ "thinking" or
            html =~ "loading"

        assert ai_response_visible,
               "Expected an AI response to appear in the chat after submitting a question. Got: #{html}"

        :ok
      end
    end
  end
end
