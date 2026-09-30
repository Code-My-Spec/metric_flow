defmodule MetricFlowSpex.Criterion802LlmFailureSurfacesErrorSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "LLM failure during refinement surfaces an error rather than a silent no-op", fail_on_error_logs: false, criterion: 802 do
    scenario "the LLM service fails to return a usable response" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user sends a follow-up refinement message and the LLM service fails", context do
        # Stubs the provider request with a plug that always errors, the same
        # shape of failure a real LLM outage would produce, without a real
        # network round trip (which is slow and depends on live account state).
        plug = fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            529,
            Jason.encode!(%{
              "type" => "error",
              "error" => %{"type" => "overloaded_error", "message" => "Overloaded"}
            })
          )
        end

        Application.put_env(:metric_flow, :req_http_options, plug: plug)

        capture_log(fn ->
          render_submit(context.view, "send_chat", %{"prompt" => "Change the color to green"})
          Process.sleep(500)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :req_http_options)

        {:ok, context}
      end

      then_ "the chat panel surfaces an error rather than leaving the user without feedback or silently leaving the spec unchanged", context do
        assert has_element?(context.view, "[data-role='chat-error']"),
               "Expected a visible chat error when the LLM call fails"

        {:ok, context}
      end
    end
  end
end
