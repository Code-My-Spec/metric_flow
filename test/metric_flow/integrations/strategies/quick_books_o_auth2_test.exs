defmodule MetricFlow.Integrations.Strategies.QuickBooksOAuth2Test do
  use ExUnit.Case, async: true

  alias MetricFlow.Integrations.Strategies.QuickBooksOAuth2

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_config do
    [
      client_id: "stub-client-id",
      client_secret: "stub-client-secret",
      redirect_uri: "http://localhost:4000/integrations/oauth/callback/quickbooks",
      base_url: "https://oauth.platform.intuit.com",
      authorize_url: "https://appcenter.intuit.com/connect/oauth2",
      token_url: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
    ]
  end

  defp valid_token do
    %{
      "access_token" => "eyJhbGciOiJSUzI1NiJ9.stub_access_token",
      "refresh_token" => "AB11stub_refresh_token",
      "token_type" => "bearer",
      "expires_in" => 3600
    }
  end

  defp non_empty_user_map do
    %{"sub" => "12345678901234567890", "email" => "user@example.com"}
  end

  # ---------------------------------------------------------------------------
  # default_config/1
  # ---------------------------------------------------------------------------

  describe "default_config/1" do
    test "returns an empty keyword list" do
      assert QuickBooksOAuth2.default_config([]) == []
    end

    test "returns an empty keyword list regardless of config argument" do
      assert QuickBooksOAuth2.default_config(valid_config()) == []
    end
  end

  # ---------------------------------------------------------------------------
  # normalize/2
  # ---------------------------------------------------------------------------

  describe "normalize/2" do
    test "returns ok tuple with the user map unchanged" do
      user = non_empty_user_map()
      assert {:ok, ^user} = QuickBooksOAuth2.normalize(valid_config(), user)
    end

    test "accepts an empty map and returns it as-is" do
      assert {:ok, %{}} = QuickBooksOAuth2.normalize(valid_config(), %{})
    end

    test "accepts a non-empty map and returns it unchanged" do
      user = non_empty_user_map()
      assert {:ok, returned_user} = QuickBooksOAuth2.normalize(valid_config(), user)
      assert returned_user == user
    end
  end

  # ---------------------------------------------------------------------------
  # fetch_user/2
  # ---------------------------------------------------------------------------

  describe "fetch_user/2" do
    test "returns ok tuple with an empty map regardless of config" do
      assert {:ok, %{}} = QuickBooksOAuth2.fetch_user([], valid_token())
      assert {:ok, %{}} = QuickBooksOAuth2.fetch_user(valid_config(), valid_token())
    end

    test "returns ok tuple with an empty map regardless of token" do
      assert {:ok, %{}} = QuickBooksOAuth2.fetch_user(valid_config(), %{})
      assert {:ok, %{}} = QuickBooksOAuth2.fetch_user(valid_config(), valid_token())
      assert {:ok, %{}} = QuickBooksOAuth2.fetch_user(valid_config(), %{"access_token" => "different-token"})
    end

    test "never raises or returns an error tuple" do
      result = QuickBooksOAuth2.fetch_user(valid_config(), valid_token())
      assert match?({:ok, _}, result)
    end
  end
end
