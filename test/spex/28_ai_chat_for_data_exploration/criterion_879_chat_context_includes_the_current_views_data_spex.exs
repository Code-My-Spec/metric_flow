defmodule MetricFlowSpex.Criterion879ChatContextIncludesTheCurrentViewsDataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Chat context includes the current view's data", criterion: 879 do
    scenario "a user opens AI chat from a specific visualization and asks a question" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user opens AI chat from a specific visualization", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        result =
          view
          |> element("[data-role='open-ai-chat']")
          |> render_click()

        chat_view =
          case result do
            {:error, {:live_redirect, %{to: to}}} ->
              {:ok, chat_view, _html} = live(context.owner_conn, to)
              chat_view

            _ ->
              flunk("Expected opening AI chat from the visualization to navigate to the chat interface")
          end

        {:ok, Map.put(context, :chat_view, chat_view)}
      end

      when_ "they view the chat before asking anything", context do
        {:ok, context}
      end

      then_ "the chat has access to the relevant data from that visualization as context", context do
        assert has_element?(context.chat_view, "[data-role='context-indicator']"),
               "Expected the chat to show a context indicator referencing the originating visualization"

        {:ok, context}
      end
    end
  end
end
