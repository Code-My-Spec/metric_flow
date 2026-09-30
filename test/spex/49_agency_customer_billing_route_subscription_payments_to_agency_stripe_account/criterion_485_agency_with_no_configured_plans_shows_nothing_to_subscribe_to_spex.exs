defmodule MetricFlowSpex.AgencyWithNoConfiguredPlansShowsNothingToSubscribeToSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Users.Scope

  spex "Agency with no configured plans shows nothing to subscribe to", criterion: 485 do
    scenario "a customer of an agency with no plans visits checkout" do
      given_ :user_logged_in_as_owner

      when_ "a platform default plan exists, and the customer signs up via an agency with no plans of its own", context do
        {:ok, _platform_plan} =
          BillingRepository.create_plan(%{
            name: "Platform Default",
            price_cents: 4999,
            currency: "usd",
            billing_interval: :monthly,
            agency_account_id: nil,
            stripe_price_id: "price_test_#{System.unique_integer([:positive])}"
          })

        owner_scope = Scope.for_user(MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email))
        owner_account_id = Accounts.get_personal_account_id(owner_scope)
        token = Agencies.generate_referral_token(owner_account_id)

        email = "customer#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register?ref=#{token}")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Customer Account"}
        )
        |> render_submit()

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        customer_conn = login_form |> submit_form(login_conn) |> recycle()

        {:ok, view, _html} = live(customer_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no purchasable plan is shown, and the platform's own default plan is not offered instead", context do
        html = render(context.view)
        refute html =~ "subscribe-button"
        refute html =~ "$49.99"
        {:ok, context}
      end
    end
  end
end
