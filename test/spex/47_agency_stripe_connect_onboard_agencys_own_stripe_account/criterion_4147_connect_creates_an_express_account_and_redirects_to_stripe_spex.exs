defmodule MetricFlowSpex.ConnectCreatesExpressAccountAndRedirectsSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Connect creates an Express account and redirects to Stripe" do
    scenario "admin clicks connect and is redirected to the onboarding URL Stripe returned" do
      given_ :user_logged_in_as_owner

      given_ "Stripe accepts the account and account-link creation calls", context do
        Application.put_env(:metric_flow, :stripe_test_plug, fn conn ->
          {status, body} =
            case {conn.method, conn.request_path} do
              {"POST", "/v1/accounts"} ->
                {200, %{"id" => "acct_test_#{System.unique_integer([:positive])}"}}

              {"POST", "/v1/account_links"} ->
                {200, %{"url" => "https://connect.stripe.com/setup/test_e2e"}}
            end

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(status, Jason.encode!(body))
        end)

        {:ok, context}
      end

      given_ "the admin is on the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin clicks connect", context do
        context.view |> element("[data-role=connect-stripe]") |> render_click()
        {:ok, context}
      end

      then_ "the admin is redirected to the Stripe onboarding URL", context do
        {path, _flash} = assert_redirect(context.view)
        assert path == "https://connect.stripe.com/setup/test_e2e"
        {:ok, context}
      end
    end
  end
end
