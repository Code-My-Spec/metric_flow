defmodule MetricFlowSpex.Criterion880UserAsksANaturalLanguageQuestionAndGetsAnAnswerSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.ClaudeCodeStub

  spex "User asks a natural-language question and gets an answer", criterion: 880 do
    scenario "a user with a revenue drop asks why revenue dropped last week" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user viewing the AI chat", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they ask why revenue dropped last week", context do
        Application.put_env(
          :metric_flow,
          :test_llm_options,
          command_runner:
            ClaudeCodeStub.text(
              "Revenue dropped last week mainly due to a decline in ad spend and lower conversion " <>
                "rates across your campaigns."
            )
        )

        capture_log(fn ->
          context.view
          |> form("form[phx-submit='send_message']", %{"content" => "Why did my revenue drop last week?"})
          |> render_submit()

          Process.sleep(100)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :test_llm_options)

        {:ok, context}
      end

      then_ "the AI responds with an explanation grounded in that data", context do
        assert has_element?(context.view, "[data-role='assistant-message']")
        {:ok, context}
      end
    end
  end
end
