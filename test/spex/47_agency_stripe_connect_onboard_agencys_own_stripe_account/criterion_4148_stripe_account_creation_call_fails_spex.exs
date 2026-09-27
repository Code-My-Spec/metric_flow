defmodule MetricFlowSpex.StripeAccountCreationCallFailsSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Stripe account creation call fails" do
    scenario "admin clicks connect and Stripe rejects the account creation" do
      given_ :user_logged_in_as_owner

      given_ "Stripe rejects the account creation call", context do
        Application.put_env(:metric_flow, :stripe_test_plug, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(402, Jason.encode!(%{"error" => %{"message" => "card_declined"}}))
        end)

        {:ok, context}
      end

      given_ "the admin is on the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin clicks connect", context do
        html = context.view |> element("[data-role=connect-stripe]") |> render_click()
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the admin sees an error instead of being redirected", context do
        assert context.html =~ "Failed to start Stripe onboarding"
        {:ok, context}
      end
    end
  end
end
