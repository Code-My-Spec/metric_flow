defmodule MetricFlow.OnboardingTest do
  use MetricFlowTest.DataCase, async: false

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Integrations
  alias MetricFlow.Onboarding
  alias MetricFlow.Onboarding.Tools

  # Google consent fixture that grants Analytics and Ads but not Search
  # Console or Business Profile (the user unticked them).
  defmodule PartialGoogleProvider do
    alias MetricFlow.Integrations.Providers.GoogleAnalytics

    def config do
      GoogleAnalytics.config()
      |> Keyword.merge(
        base_url: "https://accounts.google.com",
        authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
        token_url: "https://oauth2.googleapis.com/token",
        user_url: "https://www.googleapis.com/oauth2/v3/userinfo",
        http_adapter: {Assent.HTTPAdapter.Req, [plug: &__MODULE__.respond/1]}
      )
    end

    def strategy, do: Assent.Strategy.OAuth2
    defdelegate normalize_user(user), to: GoogleAnalytics

    def respond(%Plug.Conn{method: "POST"} = conn) do
      json(conn, %{
        "access_token" => "bundle-access",
        "refresh_token" => "bundle-refresh",
        "expires_in" => 3600,
        "token_type" => "Bearer",
        "scope" =>
          "openid email profile https://www.googleapis.com/auth/analytics.readonly " <>
            "https://www.googleapis.com/auth/adwords " <>
            "https://www.googleapis.com/auth/youtube.readonly " <>
            "https://www.googleapis.com/auth/yt-analytics.readonly"
      })
    end

    def respond(%Plug.Conn{method: "GET"} = conn) do
      json(conn, %{"sub" => "g-123", "email" => "owner@example.com", "email_verified" => true})
    end

    defp json(conn, body) do
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(body))
    end
  end

  setup do
    user = user_fixture()
    %{user: user, scope: user_scope_fixture(user)}
  end

  describe "status/1" do
    test "nothing connected", %{scope: scope} do
      [google, youtube, meta, qb] = Onboarding.status(scope)

      assert {google.key, youtube.key, meta.key, qb.key} ==
               {:google, :youtube, :facebook_ads, :quickbooks}

      assert Enum.map(google.products, & &1.key) ==
               [:google_analytics, :google_ads, :google_search_console, :google_business]

      assert Enum.map(youtube.products, & &1.key) == [:youtube]
      assert google.state == :not_connected
      assert Enum.all?(google.products, &(&1.status == :not_connected))
    end

    test "a connected Google product makes unconnected siblings :not_granted", %{
      user: user,
      scope: scope
    } do
      integration_fixture(user, %{provider: :google_analytics})
      google = Onboarding.connection_status(scope, :google)
      by_key = Map.new(google.products, &{&1.key, &1.status})

      assert by_key.google_analytics == :ready
      assert by_key.google_ads == :not_granted
      assert Onboarding.any_ready?(scope)
    end

    test "expired token without refresh needs reconnect; refreshable one doesn't", %{
      user: user,
      scope: scope
    } do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      integration_fixture(user, %{provider: :facebook_ads, expires_at: past, refresh_token: nil})
      integration_fixture(user, %{provider: :quickbooks, expires_at: past})

      statuses =
        scope
        |> Onboarding.status()
        |> Enum.flat_map(& &1.products)
        |> Map.new(&{&1.key, &1.status})

      assert statuses.facebook_ads == :reconnect
      refute statuses.quickbooks == :reconnect
    end
  end

  describe "save_selection/3" do
    test "writes the key each sync reads", %{user: user, scope: scope} do
      integration_fixture(user, %{provider: :facebook_ads, provider_metadata: %{}})
      integration_fixture(user, %{provider: :quickbooks, provider_metadata: %{}})

      assert {:ok, %{selected: ["act_1"]}} =
               Onboarding.save_selection(scope, :facebook_ads, ["act_1"])

      assert {:ok, _} = Onboarding.save_selection(scope, :quickbooks, ["10", "11"])

      {:ok, fb} = Integrations.get_integration(scope, :facebook_ads)
      {:ok, qb} = Integrations.get_integration(scope, :quickbooks)
      assert fb.provider_metadata["ad_account_id"] == "act_1"
      assert qb.provider_metadata["income_account_ids"] == ["10", "11"]
      assert qb.provider_metadata["income_account_id"] == "10"
    end

    test "validates selection count", %{user: user, scope: scope} do
      integration_fixture(user, %{provider: :google_ads})
      assert {:error, :nothing_selected} = Onboarding.save_selection(scope, :google_ads, [])

      assert {:error, :select_exactly_one} =
               Onboarding.save_selection(scope, :google_ads, ["1", "2"])

      assert {:error, :unknown_product} = Onboarding.save_selection(scope, :nope, ["1"])
    end
  end

  test "every Google product lives on one :google integration", %{user: user, scope: scope} do
    integration_fixture(user, %{provider: :google_analytics})

    integration_fixture(user, %{
      provider: :google_ads,
      provider_metadata: %{"customer_id" => "123"}
    })

    assert [%{provider: :google} = google] = Integrations.list_integrations(scope)
    assert google.provider_metadata["property_id"] == "GA4-67890"
    assert google.provider_metadata["customer_id"] == "123"

    statuses =
      scope
      |> Onboarding.connection_status(:google)
      |> Map.get(:products)
      |> Map.new(&{&1.key, &1.status})

    assert statuses == %{
             google_analytics: :ready,
             google_ads: :ready,
             google_search_console: :not_granted,
             google_business: :not_granted
           }
  end

  test "disconnecting one Google product clears its selection and keeps its siblings", %{
    user: user,
    scope: scope
  } do
    integration_fixture(user, %{provider: :google_analytics})

    integration_fixture(user, %{provider: :google_ads, provider_metadata: %{"customer_id" => "1"}})

    assert :ok = Onboarding.disconnect(scope, :google_analytics)

    {:ok, google} = Integrations.get_integration(scope, :google)
    refute Map.has_key?(google.provider_metadata, "property_id")
    assert google.provider_metadata["customer_id"] == "1"

    statuses =
      scope
      |> Onboarding.connection_status(:google)
      |> Map.get(:products)
      |> Map.new(&{&1.key, &1.status})

    assert statuses.google_analytics == :needs_selection
    assert statuses.google_ads == :ready
  end

  test "disconnecting Google removes the one Google integration", %{user: user, scope: scope} do
    integration_fixture(user, %{provider: :google_analytics})
    integration_fixture(user, %{provider: :google_ads})

    assert :ok = Onboarding.disconnect(scope, :google)
    assert {:error, :not_found} = Integrations.get_integration(scope, :google)
    assert Onboarding.connection_status(scope, :google).state == :not_connected
  end

  describe "Google bundle callback" do
    setup do
      original = Application.get_env(:metric_flow, :oauth_providers)

      Application.put_env(:metric_flow, :oauth_providers, %{
        google_analytics: PartialGoogleProvider
      })

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :oauth_providers, original),
          else: Application.delete_env(:metric_flow, :oauth_providers)
      end)
    end

    test "authorize URL asks for every Google product scope" do
      {:ok, %{url: url, session_params: params}} = Integrations.google_bundle_authorize_url()
      query = url |> URI.parse() |> Map.get(:query) |> URI.decode_query()

      for scope <- List.flatten(Map.values(Integrations.google_product_scopes())),
          do: assert(query["scope"] =~ scope)

      # YouTube has its own sign-in.
      refute query["scope"] =~ "youtube"

      assert query["include_granted_scopes"] == "true"
      assert params.google_bundle
    end

    test "upserts the one :google integration, keeping existing selections", %{
      user: user,
      scope: scope
    } do
      integration_fixture(user, %{
        provider: :google_ads,
        provider_metadata: %{"customer_id" => "123"}
      })

      assert {:ok,
              %{
                connected: [:google_ads, :google_analytics],
                not_granted: [:google_business, :google_search_console]
              }} =
               Integrations.handle_google_bundle_callback(
                 scope,
                 %{state: "s1"},
                 %{"code" => "c", "state" => "s1"}
               )

      assert [%{provider: :google} = google] = Integrations.list_integrations(scope)
      assert google.provider_metadata["customer_id"] == "123"
      assert google.access_token == "bundle-access"
      assert Integrations.product_granted?(google, :google_analytics)
      refute Integrations.product_granted?(google, :google_search_console)
      refute Integrations.connected?(scope, :youtube)

      statuses =
        scope
        |> Onboarding.connection_status(:google)
        |> Map.get(:products)
        |> Map.new(&{&1.key, &1.status})

      assert statuses.google_ads == :ready
      assert statuses.google_analytics == :needs_selection
      assert statuses.google_search_console == :not_granted
    end

    test "a callback without stored state is rejected", %{scope: scope} do
      assert {:error, :missing_stored_state} =
               Integrations.handle_google_bundle_callback(scope, %{}, %{"code" => "c"})
    end
  end

  describe "Tools" do
    test "chat mode reports status and returns a connect link", %{scope: scope} do
      assert {:ok, %{connections: [_, _, _, _]}} =
               Tools.call(:chat, "get_setup_status", %{}, %{scope: scope})

      assert {:ok, %{url: url}} =
               Tools.call(:chat, "get_connect_link", %{"connection" => "google"}, %{scope: scope})

      assert url =~ "/app/integrations/oauth/google_bundle"

      assert {:ok, %{url: youtube_url}} =
               Tools.call(:chat, "get_connect_link", %{"connection" => "youtube"}, %{scope: scope})

      assert youtube_url =~ "/app/integrations/oauth/youtube"

      assert {:error, _} =
               Tools.call(:chat, "get_connect_link", %{"connection" => "x"}, %{scope: scope})
    end

    test "chat mode hides account selection; MCP mode adds it" do
      chat = Tools.specs(:chat)
      refute Enum.any?(chat, &(&1.name == "list_accounts"))
      refute Enum.any?(chat, &Map.has_key?(&1.input_schema.properties, :account_id))

      [list | rest] = Tools.specs(:mcp)
      assert list.name == "list_accounts"
      assert Enum.all?(rest, &Map.has_key?(&1.input_schema.properties, :account_id))
    end

    test "MCP mode defaults account_id for a single-account user", %{user: user} do
      integration_fixture(user, %{provider: :google_analytics})

      assert {:ok, %{connections: conns}} =
               Tools.call(:mcp, "get_setup_status", %{}, %{user: user})

      assert Enum.find(conns, &(&1.connection == :google)).state == :done

      assert {:ok, %{accounts: [%{role: :owner, can_change_setup: true, setup: setup}]}} =
               Tools.call(:mcp, "list_accounts", %{}, %{user: user})

      assert setup =~ "Google: done"
    end

    test "writes need a write role", %{user: user} do
      viewer = user_fixture()
      account_id = default_account_id(user)

      %MetricFlow.Accounts.AccountMember{}
      |> MetricFlow.Accounts.AccountMember.changeset(%{
        account_id: account_id,
        user_id: viewer.id,
        role: :read_only
      })
      |> MetricFlow.Repo.insert!()

      args = %{"account_id" => account_id, "product" => "google_analytics"}

      assert {:error, "Your role on this account is read-only" <> _} =
               Tools.call(:mcp, "disconnect_product", args, %{user: viewer})

      assert {:ok, _} = Tools.call(:mcp, "get_setup_status", args, %{user: viewer})
    end
  end
end
