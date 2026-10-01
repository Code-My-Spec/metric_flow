defmodule MetricFlowSpex.Criterion217UserCanShareChatInsightsWithTeamMembersSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.ClaudeCodeStub

  spex "User can share chat insights with team members", criterion: 217 do
    scenario "a user shares an AI insight and a team member opens the link" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics
      given_ :owner_has_member_with_access

      given_ "a user has received a useful insight from AI chat", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")

        Application.put_env(
          :metric_flow,
          :test_llm_options,
          command_runner:
            ClaudeCodeStub.text(
              "Your best-performing channel this month is Google Ads, with the highest conversion " <>
                "rate among your connected platforms."
            )
        )

        capture_log(fn ->
          view
          |> form("form[phx-submit='send_message']", %{"content" => "What is my best-performing channel?"})
          |> render_submit()

          Process.sleep(100)
          render(view)
        end)

        Application.delete_env(:metric_flow, :test_llm_options)

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they share it with a team member", context do
        html_before = render(context.view)

        context.view
        |> element("[data-role='share-insight']")
        |> render_click()

        [_, session_id] = Regex.run(~r/data-session-id="(\d+)"/, html_before)

        {:ok, Map.put(context, :shared_session_id, session_id)}
      end

      then_ "that team member can view the shared insight", context do
        {:ok, second_login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(second_login_view, "#login_form_password",
            user: %{
              email: context.member_email,
              password: context.member_password,
              remember_me: true
            }
          )

        second_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, shared_view, html} = live(second_conn, "/app/chat/#{context.shared_session_id}")

        assert has_element?(shared_view, "[data-role='assistant-message']"),
               "Expected the team member to see the shared insight: #{html}"

        {:ok, context}
      end
    end
  end
end
