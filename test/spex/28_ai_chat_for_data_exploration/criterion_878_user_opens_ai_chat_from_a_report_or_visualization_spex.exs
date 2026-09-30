defmodule MetricFlowSpex.Criterion878UserOpensAiChatFromAReportOrVisualizationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User opens AI chat from a report or visualization", criterion: 878 do
    scenario "a user viewing a visualization opens AI chat from that view" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user viewing a visualization", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they open AI chat", context do
        result =
          context.view
          |> element("[data-role='open-ai-chat']")
          |> render_click()

        {:ok, Map.put(context, :click_result, result)}
      end

      then_ "the chat interface opens from that view", context do
        case context.click_result do
          {:error, {:live_redirect, %{to: to}}} ->
            {:ok, chat_view, _html} = live(context.owner_conn, to)
            assert has_element?(chat_view, "[data-role='conversation-area']")

          _ ->
            flunk("Expected opening AI chat from the visualization to navigate to the chat interface")
        end

        {:ok, context}
      end
    end
  end
end
