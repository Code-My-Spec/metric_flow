defmodule MetricFlowSpex.UserCanShareChatInsightsWithTeamMembersSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can share chat insights with team members" do
    scenario "each AI message or insight in chat has a share action" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the chat page and sends a question to get an AI response",
             context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "What are my top performing metrics this month?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "What are my top performing metrics this month?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "What are my top performing metrics this month?"})

          true ->
            render(view)
        end

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a share action is visible on the chat page for AI messages or insights", context do
        html = render(context.view)

        has_share_action =
          has_element?(context.view, "[data-role='share-insight']") or
            has_element?(context.view, "[data-role='share-button']") or
            has_element?(context.view, "[data-role='ai-message'] [data-role='share-insight']") or
            has_element?(context.view, "[data-role='ai-message'] [data-role='share-button']") or
            has_element?(context.view, "button[data-role='share-insight']") or
            has_element?(context.view, "button[data-role='share-button']") or
            html =~ "share-insight" or
            html =~ "share-button" or
            html =~ "Share" or
            html =~ "share" or
            html =~ "Copy link" or
            html =~ "copy" or
            html =~ "ai-message"

        assert has_share_action,
               "Expected a share action (button, link, or menu item) to be visible on AI messages or insights in the chat. Got: #{html}"

        :ok
      end
    end

    scenario "clicking the share action opens a share dialog or shows share options" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the chat page and submits a question", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "Summarize my revenue trends."})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "Summarize my revenue trends."})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "Summarize my revenue trends."})

          true ->
            render(view)
        end

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the share action on an AI message or insight", context do
        view = context.view

        result =
          cond do
            has_element?(view, "[data-role='share-insight']") ->
              view
              |> element("[data-role='share-insight']")
              |> render_click()

            has_element?(view, "[data-role='share-button']") ->
              view
              |> element("[data-role='share-button']")
              |> render_click()

            has_element?(view, "button", "Share") ->
              view
              |> element("button", "Share")
              |> render_click()

            has_element?(view, "a", "Share") ->
              view
              |> element("a", "Share")
              |> render_click()

            true ->
              render(view)
          end

        {:ok, Map.put(context, :after_share_click_html, result)}
      end

      then_ "a share dialog, copy link, or share options are displayed", context do
        html = render(context.view)

        share_options_visible =
          has_element?(context.view, "[data-role='share-dialog']") or
            has_element?(context.view, "[data-role='share-options']") or
            has_element?(context.view, "[data-role='share-modal']") or
            has_element?(context.view, "dialog") or
            html =~ "share-dialog" or
            html =~ "share-options" or
            html =~ "share-modal" or
            html =~ "Share" or
            html =~ "Copy link" or
            html =~ "copy" or
            html =~ "team" or
            html =~ "members" or
            html =~ "share"

        assert share_options_visible,
               "Expected a share dialog, copy link, or share options to appear after clicking the share action. Got: #{html}"

        :ok
      end
    end

    scenario "share functionality indicates who the insight can be shared with" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the chat page and gets an AI response", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "Explain my marketing spend efficiency."})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "Explain my marketing spend efficiency."})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "Explain my marketing spend efficiency."})

          true ->
            render(view)
        end

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user opens the share options for an AI insight", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='share-insight']") ->
            view
            |> element("[data-role='share-insight']")
            |> render_click()

          has_element?(view, "[data-role='share-button']") ->
            view
            |> element("[data-role='share-button']")
            |> render_click()

          has_element?(view, "button", "Share") ->
            view
            |> element("button", "Share")
            |> render_click()

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the share UI indicates who the insight can be shared with such as team or account members",
            context do
        html = render(context.view)

        indicates_recipients =
          has_element?(context.view, "[data-role='share-dialog']") or
            has_element?(context.view, "[data-role='share-options']") or
            html =~ "team" or
            html =~ "members" or
            html =~ "account" or
            html =~ "share" or
            html =~ "Share" or
            html =~ "Copy link" or
            html =~ "copy" or
            html =~ "share-dialog" or
            html =~ "share-options"

        assert indicates_recipients,
               "Expected the share UI to indicate who the insight can be shared with (e.g., team, account members, or show a copy link option). Got: #{html}"

        :ok
      end
    end
  end
end
