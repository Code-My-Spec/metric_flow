defmodule MetricFlowSpex.Criterion885UserSharesAChatInsightWithATeamMemberSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import ReqCassette

  import MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/ai",
    filter_request_headers: ["x-api-key", "authorization"],
    mode: :replay,
    match_requests_on: [:method, :uri]
  ]

  spex "User shares a chat insight with a team member", criterion: 885 do
    scenario "a user shares an AI insight and a team member opens the link" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics
      given_ :second_user_registered

      given_ "a user has received a useful insight from AI chat", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")

        with_cassette "chat_shareable_insight", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :test_llm_options, req_http_options: [plug: plug])

          capture_log(fn ->
            view
            |> form("form[phx-submit='send_message']", %{"content" => "What is my best-performing channel?"})
            |> render_submit()

            Process.sleep(100)
            render(view)
          end)

          Application.delete_env(:metric_flow, :test_llm_options)
        end

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
              email: context.second_user_email,
              password: context.second_user_password,
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
