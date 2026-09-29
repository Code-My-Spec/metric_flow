defmodule MetricFlowSpex.SharedGivens do
  @moduledoc """
  Shared given steps for BDD specifications.

  Import these givens in your spec files:

      defmodule MetricFlowSpex.FeatureNameSpex do
        use SexySpex
        import MetricFlowSpex.SharedGivens
        # ...
      end

  **Every given merges into the context it is handed, never replaces it.**
  Givens compose — `given_ :user_logged_in_as_owner` followed by
  `given_ :owner_has_active_subscription` means the second one runs on the
  first one's context — so a given that answers a fresh map erases whatever ran
  before it. That is not a hypothetical: all twelve of these did it, and the
  121 spex that failed with `key :owner_conn not found in: %{}` were reading a
  context a later given had thrown away.

  Add new shared givens here when you find yourself duplicating setup code
  across multiple specs. Remember: spex files can only access the Web layer,
  so shared givens should set up state through UI interactions, not fixtures.
  """

  use SexySpex.Givens

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Metrics.NormalizedMetric
  alias MetricFlow.Users.Scope

  @endpoint MetricFlowWeb.Endpoint

  register_given :user_registered_with_password, context do
    email = "testuser#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    conn = Phoenix.ConnTest.build_conn()
    {:ok, view, _html} = live(conn, "/users/register")

    view
    |> form("#registration_form",
      user: %{
        email: email,
        password: password,
        account_name: "Test Account"
      }
    )
    |> render_submit()

    # Drain all emails from the mailbox so they don't interfere with later assert_email_sent calls
    Process.sleep(50)

    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end

    drain.(drain)

    {:ok, Map.merge(context, %{registered_email: email, registered_password: password})}
  end

  register_given :user_logged_in_as_owner, context do
    email = "owner#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    # Register through UI
    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form",
      user: %{
        email: email,
        password: password,
        account_name: "Owner Account"
      }
    )
    |> render_submit()

    # Drain all emails from the mailbox so they don't interfere with later assert_email_sent calls
    Process.sleep(50)

    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end

    drain.(drain)

    # Log in through UI
    login_conn = build_conn()
    {:ok, login_view, _html} = live(login_conn, "/users/log-in")

    login_form =
      form(login_view, "#login_form_password",
        user: %{
          email: email,
          password: password,
          remember_me: true
        }
      )

    logged_in_conn = submit_form(login_form, login_conn)
    authed_conn = recycle(logged_in_conn)

    {:ok,
     Map.merge(context, %{
       owner_conn: authed_conn,
       owner_email: email,
       owner_password: password
     })}
  end

  register_given :owner_with_integrations, context do
    email = "owner#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    # Register through UI to create a user and account
    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form",
      user: %{
        email: email,
        password: password,
        account_name: "Owner Account"
      }
    )
    |> render_submit()

    # Drain all emails from the mailbox so they don't interfere with later assert_email_sent calls
    Process.sleep(50)

    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end

    drain.(drain)

    # Look up the created user to insert an integration fixture
    user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
    MetricFlowTest.IntegrationsFixtures.integration_fixture(user)

    # Log in through UI
    login_conn = build_conn()
    {:ok, login_view, _html} = live(login_conn, "/users/log-in")

    login_form =
      form(login_view, "#login_form_password",
        user: %{
          email: email,
          password: password,
          remember_me: true
        }
      )

    logged_in_conn = submit_form(login_form, login_conn)
    authed_conn = recycle(logged_in_conn)

    {:ok,
     Map.merge(context, %{
       owner_conn: authed_conn,
       owner_email: email,
       owner_password: password
     })}
  end

  register_given :second_user_registered, context do
    email = "member#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form",
      user: %{
        email: email,
        password: password,
        account_name: "Member Account"
      }
    )
    |> render_submit()

    # Drain all emails from the mailbox so they don't interfere with later assert_email_sent calls
    Process.sleep(50)

    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end

    drain.(drain)

    {:ok, Map.merge(context, %{second_user_email: email, second_user_password: password})}
  end

  register_given :agency_member_registered, context do
    email = "member#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    # Register through UI, then join them to the owner's agency account
    # directly: no UI path adds an existing user to another account with a
    # chosen role, so specs asserting on non-admin restrictions need this.
    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form",
      user: %{
        email: email,
        password: password,
        account_name: "Member Personal Account"
      }
    )
    |> render_submit()

    Process.sleep(50)

    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end

    drain.(drain)

    owner = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
    member = MetricFlowTest.UsersFixtures.get_user_by_email(email)
    owner_scope = Scope.for_user(owner)
    agency_account_id = MetricFlow.Accounts.get_personal_account_id(owner_scope)

    {:ok, _account_member} =
      %AccountMember{}
      |> AccountMember.changeset(%{
        account_id: agency_account_id,
        user_id: member.id,
        role: :member
      })
      |> MetricFlow.Repo.insert()

    login_conn = build_conn()
    {:ok, login_view, _html} = live(login_conn, "/users/log-in")

    login_form =
      form(login_view, "#login_form_password",
        user: %{
          email: email,
          password: password,
          remember_me: true
        }
      )

    logged_in_conn = submit_form(login_form, login_conn)
    authed_conn = recycle(logged_in_conn)

    {:ok,
     Map.merge(context, %{
       member_conn: authed_conn,
       member_email: email,
       member_password: password
     })}
  end

  register_given :owner_with_google_ads_integration, context do
    email = "owner#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    # Register through UI
    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form",
      user: %{
        email: email,
        password: password,
        account_name: "Owner Account"
      }
    )
    |> render_submit()

    Process.sleep(50)

    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end

    drain.(drain)

    # Create integration fixture
    user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
    MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :google_analytics})

    # Log in through UI
    login_conn = build_conn()
    {:ok, login_view, _html} = live(login_conn, "/users/log-in")

    login_form =
      form(login_view, "#login_form_password",
        user: %{
          email: email,
          password: password,
          remember_me: true
        }
      )

    logged_in_conn = submit_form(login_form, login_conn)
    authed_conn = recycle(logged_in_conn)

    {:ok,
     Map.merge(context, %{
       owner_conn: authed_conn,
       owner_email: email,
       owner_password: password
     })}
  end

  register_given :owner_with_quickbooks_integration, context do
    email = "owner#{System.unique_integer([:positive])}@example.com"
    password = "SecurePassword123!"

    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form",
      user: %{
        email: email,
        password: password,
        account_name: "Owner Account"
      }
    )
    |> render_submit()

    Process.sleep(50)

    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end

    drain.(drain)

    user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
    MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :quickbooks})

    login_conn = build_conn()
    {:ok, login_view, _html} = live(login_conn, "/users/log-in")

    login_form =
      form(login_view, "#login_form_password",
        user: %{
          email: email,
          password: password,
          remember_me: true
        }
      )

    logged_in_conn = submit_form(login_form, login_conn)
    authed_conn = recycle(logged_in_conn)

    {:ok,
     Map.merge(context, %{
       owner_conn: authed_conn,
       owner_email: email,
       owner_password: password
     })}
  end

  register_given :owner_has_active_subscription, context do
    # Creates an active subscription for the test user's account
    # so paywalled routes (correlations, AI) don't redirect to checkout
    user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
    scope = Scope.for_user(user)
    account_id = MetricFlow.Accounts.get_personal_account_id(scope)

    {:ok, _subscription} =
      BillingRepository.upsert_subscription(%{
        stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
        stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
        status: :active,
        account_id: account_id,
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })

    {:ok, context}
  end

  register_given :owner_has_agency_plan, context do
    user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
    scope = Scope.for_user(user)
    account_id = MetricFlow.Accounts.get_personal_account_id(scope)

    {:ok, plan} =
      BillingRepository.create_plan(%{
        name: "Agency Pro Plan",
        price_cents: 4999,
        currency: "usd",
        billing_interval: :monthly,
        agency_account_id: account_id,
        stripe_price_id: "price_test_#{System.unique_integer([:positive])}"
      })

    {:ok, Map.merge(context, %{agency_plan: plan})}
  end

  register_given :owner_has_stripe_connect, context do
    user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
    scope = Scope.for_user(user)
    account_id = MetricFlow.Accounts.get_personal_account_id(scope)

    {:ok, _stripe_account} =
      BillingRepository.upsert_stripe_account(%{
        stripe_account_id: "acct_test_#{System.unique_integer([:positive])}",
        agency_account_id: account_id,
        onboarding_status: :complete,
        capabilities: %{charges_enabled: true, payouts_enabled: true}
      })

    # A stub, not a recorded cassette: creating more than one plan in the same
    # scenario means more than one Stripe product+price call, and a cassette
    # replaying a fixed price ID would give every plan the same
    # `stripe_price_id`, tripping Plan's `unique_constraint` on the second
    # insert. This answers a LiveView process that never receives an
    # explicit `:plug` opt the way a direct StripeClient test would.
    Application.put_env(:metric_flow, :stripe_test_plug, &stripe_stub_plug/1)

    {:ok, context}
  end

  defp stripe_stub_plug(conn) do
    {status, body} =
      case {conn.method, conn.request_path} do
        {"POST", "/v1/products"} ->
          {200, %{"id" => "prod_test_#{System.unique_integer([:positive])}", "object" => "product"}}

        {"POST", "/v1/prices"} ->
          {200, %{"id" => "price_test_#{System.unique_integer([:positive])}", "object" => "price"}}

        {"DELETE", "/v1/accounts/" <> account_id} ->
          {200, %{"id" => account_id, "object" => "account", "deleted" => true}}
      end

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
  end

  register_given :owner_has_incomplete_stripe_connect, context do
    user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
    scope = Scope.for_user(user)
    account_id = MetricFlow.Accounts.get_personal_account_id(scope)

    {:ok, _stripe_account} =
      BillingRepository.upsert_stripe_account(%{
        stripe_account_id: "acct_test_#{System.unique_integer([:positive])}",
        agency_account_id: account_id,
        onboarding_status: :restricted,
        capabilities: %{}
      })

    {:ok, context}
  end

  register_given :owner_subscription_past_due, context do
    user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
    scope = Scope.for_user(user)
    account_id = MetricFlow.Accounts.get_personal_account_id(scope)

    {:ok, _subscription} =
      BillingRepository.upsert_subscription(%{
        stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
        stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
        status: :past_due,
        account_id: account_id,
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })

    {:ok, context}
  end

  register_given :second_user_has_agency_plan_subscription, context do
    user = MetricFlowTest.UsersFixtures.get_user_by_email(context.second_user_email)
    scope = Scope.for_user(user)
    account_id = MetricFlow.Accounts.get_personal_account_id(scope)

    {:ok, subscription} =
      BillingRepository.upsert_subscription(%{
        stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
        stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
        status: :active,
        account_id: account_id,
        plan_id: context.agency_plan.id,
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })

    login_conn = build_conn()
    {:ok, login_view, _html} = live(login_conn, "/users/log-in")

    login_form =
      form(login_view, "#login_form_password",
        user: %{
          email: context.second_user_email,
          password: context.second_user_password,
          remember_me: true
        }
      )

    logged_in_conn = submit_form(login_form, login_conn)
    second_user_conn = recycle(logged_in_conn)

    {:ok,
     Map.merge(context, %{
       second_user_conn: second_user_conn,
       second_user_subscription_id: subscription.id
     })}
  end

  register_given :globex_agency_plan_and_customer, context do
    globex_email = "globex#{System.unique_integer([:positive])}@example.com"
    globex_password = "SecurePassword123!"

    reg_conn = build_conn()
    {:ok, reg_view, _html} = live(reg_conn, "/users/register")

    reg_view
    |> form("#registration_form",
      user: %{email: globex_email, password: globex_password, account_name: "Globex Agency"}
    )
    |> render_submit()

    Process.sleep(50)

    drain = fn drain_fn ->
      receive do
        {:email, _} -> drain_fn.(drain_fn)
      after
        0 -> :ok
      end
    end

    drain.(drain)

    globex_user = MetricFlowTest.UsersFixtures.get_user_by_email(globex_email)
    globex_scope = Scope.for_user(globex_user)
    globex_account_id = MetricFlow.Accounts.get_personal_account_id(globex_scope)

    {:ok, globex_plan} =
      BillingRepository.create_plan(%{
        name: "Globex Plan",
        price_cents: 3999,
        currency: "usd",
        billing_interval: :monthly,
        agency_account_id: globex_account_id,
        stripe_price_id: "price_test_#{System.unique_integer([:positive])}"
      })

    globex_subscription =
      MetricFlowSpex.Fixtures.agency_customer_subscription!(globex_email, globex_plan)

    {:ok,
     Map.merge(context, %{
       globex_account_id: globex_account_id,
       globex_subscription_id: globex_subscription.id,
       globex_customer_identifier: globex_subscription.stripe_customer_id
     })}
  end

  register_given :owner_has_metrics, context do
    user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
    now = DateTime.utc_now()

    metrics =
      for {name, i} <-
            Enum.with_index(["impressions", "clicks", "spend", "conversions", "sessions"]) do
        %{
          metric_name: name,
          normalized_metric_name: NormalizedMetric.normalize(:google_analytics, name),
          metric_type: "raw",
          value: 100.0 + i,
          recorded_at: DateTime.add(now, -i, :day),
          provider: :google_analytics,
          dimensions: %{},
          user_id: user.id,
          inserted_at: now,
          updated_at: now
        }
      end

    MetricFlow.Repo.insert_all(MetricFlow.Metrics.Metric, metrics)

    {:ok, context}
  end

  @doc """
  Signs a JSON payload with the Stripe webhook secret for testing.
  Returns the Stripe-Signature header value.
  """
  def sign_webhook_payload(payload) when is_binary(payload) do
    secret = Application.get_env(:metric_flow, :stripe_webhook_secret, "whsec_test")
    timestamp = to_string(System.system_time(:second))
    signed_payload = "#{timestamp}.#{payload}"

    signature =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signature}"
  end

  register_given :with_oauth_stub_providers, context do
    MetricFlowTest.OAuthStub.setup_oauth_providers()
    {:ok, Map.merge(context, %{oauth_state: MetricFlowTest.OAuthStub.state_token()})}
  end

  register_given :with_ai_stubs, context do
    MetricFlowTest.AiStub.setup_ai_stubs()
    {:ok, context}
  end
end
