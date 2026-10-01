defmodule MetricFlowSpex.Criterion884ChatHistoryPersistsPerUserAcrossSessionsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.ClaudeCodeStub

  spex "Chat history persists per user across sessions", criterion: 884 do
    scenario "a user returns to the chat in a later session" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user has previously chatted with the AI", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")

        Application.put_env(
          :metric_flow,
          :test_llm_options,
          command_runner:
            ClaudeCodeStub.text(
              "Your metrics are trending steadily this month, with revenue up modestly week over week."
            )
        )

        capture_log(fn ->
          view
          |> form("form[phx-submit='send_message']", %{"content" => "How are my metrics trending?"})
          |> render_submit()

          Process.sleep(100)
          render(view)
        end)

        Application.delete_env(:metric_flow, :test_llm_options)

        {:ok, context}
      end

      when_ "they return in a later session", context do
        {:ok, reopened_view, _html} = live(context.owner_conn, "/app/chat")
        {:ok, Map.put(context, :reopened_view, reopened_view)}
      end

      then_ "their prior chat history is still available", context do
        assert has_element?(context.reopened_view, "[data-role='session-item']"),
               "Expected the sidebar to show the prior chat session"

        {:ok, context}
      end
    end
  end
end
