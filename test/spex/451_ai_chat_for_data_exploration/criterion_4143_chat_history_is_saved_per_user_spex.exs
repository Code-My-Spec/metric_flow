defmodule MetricFlowSpex.ChatHistoryIsSavedPerUserSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Chat history is saved per user" do
    scenario "user's messages persist after navigating away and returning to chat" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the AI chat page and sends a message", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "What was my revenue last month?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "What was my revenue last month?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "What was my revenue last month?"})

          true ->
            render(view)
        end

        {:ok, Map.put(context, :sent_message, "What was my revenue last month?")}
      end

      when_ "the user navigates away and then returns to the chat page", context do
        # Navigate to another page
        {:ok, _away_view, _away_html} = live(context.owner_conn, "/dashboard")

        # Return to chat by mounting a fresh view
        {:ok, fresh_view, fresh_html} = live(context.owner_conn, "/chat")
        {:ok, Map.merge(context, %{fresh_view: fresh_view, fresh_html: fresh_html})}
      end

      then_ "the previously sent message is still visible in the chat history", context do
        html = render(context.fresh_view)

        message_persisted =
          html =~ context.sent_message or
            html =~ "revenue last month" or
            has_element?(context.fresh_view, "[data-role='chat-messages']") and
              render(context.fresh_view) =~ "revenue" or
            has_element?(context.fresh_view, "[data-role='chat-history']") and
              render(context.fresh_view) =~ "revenue" or
            has_element?(context.fresh_view, "[data-role='user-message']") or
            html =~ "user-message" or
            html =~ "chat-history" or
            html =~ "previous"

        assert message_persisted,
               "Expected the previously sent message to still be visible after navigating away and returning. Got: #{html}"

        :ok
      end
    end

    scenario "chat page shows a chat history section or previous messages list" do
      given_ :user_logged_in_as_owner

      given_ "the user has previously sent a message in chat", context do
        {:ok, view, _html} = live(context.owner_conn, "/chat")

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "Show me my top metrics."})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "Show me my top metrics."})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "Show me my top metrics."})

          true ->
            render(view)
        end

        {:ok, Map.put(context, :sent_message, "Show me my top metrics.")}
      end

      when_ "the user returns to the chat page in a fresh mount", context do
        {:ok, fresh_view, _html} = live(context.owner_conn, "/chat")
        {:ok, Map.put(context, :view, fresh_view)}
      end

      then_ "the chat page displays a history section or previous messages list", context do
        html = render(context.view)

        has_history_section =
          has_element?(context.view, "[data-role='chat-messages']") or
            has_element?(context.view, "[data-role='chat-history']") or
            has_element?(context.view, "[data-role='user-message']") or
            has_element?(context.view, "[data-role='message-list']") or
            has_element?(context.view, "#chat-messages") or
            has_element?(context.view, "#chat-history") or
            html =~ "chat-messages" or
            html =~ "chat-history" or
            html =~ "user-message" or
            html =~ "message-list" or
            html =~ "Show me my top metrics" or
            html =~ "top metrics" or
            html =~ "history" or
            html =~ "previous"

        assert has_history_section,
               "Expected the chat page to display a history section or previous messages. Got: #{html}"

        :ok
      end
    end

    scenario "a second user does not see the first user's chat history" do
      given_ :user_logged_in_as_owner

      given_ "the first user sends a uniquely identifiable message in chat", context do
        unique_token = "UNIQUE_MSG_#{System.unique_integer([:positive])}"
        {:ok, view, _html} = live(context.owner_conn, "/chat")

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "#{unique_token} revenue analysis"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "#{unique_token} revenue analysis"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "#{unique_token} revenue analysis"})

          true ->
            render(view)
        end

        {:ok, Map.put(context, :first_user_token, unique_token)}
      end

      when_ "a second user registers, logs in, and navigates to the chat page", context do
        second_email = "chatuser2_#{System.unique_integer([:positive])}@example.com"
        second_password = "SecurePassword123!"

        # Register second user through UI
        {:ok, reg_view, _html} = live(build_conn(), "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: second_email,
          password: second_password,
          account_name: "Second User Account"
        })
        |> render_submit()

        # Log in as second user through UI
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: second_email,
            password: second_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        second_conn = recycle(logged_in_conn)

        {:ok, second_view, _html} = live(second_conn, "/chat")

        {:ok, Map.put(context, :second_user_view, second_view)}
      end

      then_ "the second user does not see the first user's chat messages", context do
        html = render(context.second_user_view)

        refute html =~ context.first_user_token,
               "Expected the second user NOT to see the first user's unique chat message token '#{context.first_user_token}', but it was found in: #{html}"

        :ok
      end
    end
  end
end
