defmodule MetricFlowSpex.Criterion214AiHasAccessToAllMetricsAndCorrelationDataToAnswerSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.ClaudeCodeStub

  spex "AI has access to all metrics and correlation data to answer", criterion: 214 do
    scenario "a question spans metrics beyond the current view" do
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

      when_ "the user asks a question spanning metrics beyond that view", context do
        Application.put_env(
          :metric_flow,
          :test_llm_options,
          command_runner:
            ClaudeCodeStub.text(
              "Across your connected platforms, conversions correlate positively with ad spend -- " <>
                "increasing budget on your top channel should continue to drive growth."
            )
        )

        capture_log(fn ->
          context.chat_view
          |> form("form[phx-submit='send_message']", %{
            "content" => "How do my conversions correlate with ad spend across all my platforms?"
          })
          |> render_submit()

          Process.sleep(100)
          render(context.chat_view)
        end)

        Application.delete_env(:metric_flow, :test_llm_options)

        {:ok, context}
      end

      then_ "it draws on the full set of available metrics and correlation data, not just the current view", context do
        assert has_element?(context.chat_view, "[data-role='assistant-message']")
        {:ok, context}
      end
    end
  end
end
