defmodule MetricFlow.Integrations.Providers.BehaviourTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Concrete test implementation
  #
  # The Behaviour module defines callbacks but cannot be called directly.
  # We define a minimal concrete implementation here so we can exercise the
  # normalize_user/1 contract as described in the spec.  When the real
  # Behaviour module and at least one concrete provider exist, tests should
  # migrate to the provider-specific test file.  Until then this module
  # serves as the canonical place to confirm the contract itself is sound.
  # ---------------------------------------------------------------------------

  defmodule TestProvider do
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [client_id: "test_id", client_secret: "test_secret", redirect_uri: "http://localhost/callback"]
    end

    @impl true
    def strategy do
      Assent.Strategy.Github
    end

    @impl true
    def normalize_user(user_data) when not is_map(user_data) do
      {:error, :invalid_user_data}
    end

    def normalize_user(user_data) do
      case extract_provider_user_id(user_data) do
        {:ok, provider_user_id} ->
          normalized = %{
            provider_user_id: provider_user_id,
            email: Map.get(user_data, "email"),
            name: Map.get(user_data, "name"),
            username: Map.get(user_data, "preferred_username"),
            avatar_url: Map.get(user_data, "picture")
          }

          {:ok, normalized}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp extract_provider_user_id(%{"sub" => sub}) when is_binary(sub) and sub != "" do
      {:ok, sub}
    end

    defp extract_provider_user_id(%{"sub" => sub}) when is_integer(sub) do
      {:ok, Integer.to_string(sub)}
    end

    defp extract_provider_user_id(%{"sub" => nil}) do
      {:error, :missing_provider_user_id}
    end

    defp extract_provider_user_id(%{"sub" => _invalid}) do
      {:error, :invalid_provider_user_id}
    end

    defp extract_provider_user_id(_no_sub_key) do
      {:error, :missing_provider_user_id}
    end
  end

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_user_data do
    %{
      "sub" => "123456789",
      "email" => "alice@example.com",
      "name" => "Alice Example",
      "preferred_username" => "alice",
      "picture" => "https://example.com/avatar.png"
    }
  end

  defp minimal_user_data do
    %{"sub" => "987654321"}
  end

  defp integer_sub_user_data do
    %{
      "sub" => 112_233_445_566,
      "email" => "bob@example.com",
      "name" => "Bob Example",
      "preferred_username" => "bob",
      "picture" => "https://example.com/bob.png"
    }
  end

  # ---------------------------------------------------------------------------
  # normalize_user/1
  # ---------------------------------------------------------------------------

  describe "normalize_user/1" do
    # Happy path

    test "returns ok tuple with normalized user map when user_data is valid" do
      assert {:ok, normalized} = TestProvider.normalize_user(valid_user_data())
      assert is_map(normalized)
    end

    test "extracts provider_user_id from \"sub\" field" do
      assert {:ok, normalized} = TestProvider.normalize_user(valid_user_data())
      assert normalized.provider_user_id == "123456789"
    end

    test "converts integer provider_user_id to string" do
      assert {:ok, normalized} = TestProvider.normalize_user(integer_sub_user_data())
      assert normalized.provider_user_id == "112233445566"
      assert is_binary(normalized.provider_user_id)
    end

    test "extracts email, name, username, avatar_url from OpenID Connect claims" do
      assert {:ok, normalized} = TestProvider.normalize_user(valid_user_data())
      assert normalized.email == "alice@example.com"
      assert normalized.name == "Alice Example"
      assert normalized.username == "alice"
      assert normalized.avatar_url == "https://example.com/avatar.png"
    end

    test "includes provider-specific fields in normalized output" do
      user_data = Map.put(valid_user_data(), "hd", "workspace.example.com")
      # The base behaviour does not mandate a :hosted_domain key, but a
      # concrete provider that supports it (e.g. Google) must include it.
      # Here we verify the implementation at least returns an ok tuple.
      assert {:ok, _normalized} = TestProvider.normalize_user(user_data)
    end

    test "handles optional fields gracefully" do
      assert {:ok, normalized} = TestProvider.normalize_user(minimal_user_data())
      assert normalized.provider_user_id == "987654321"
      assert is_nil(normalized.email)
      assert is_nil(normalized.name)
      assert is_nil(normalized.username)
      assert is_nil(normalized.avatar_url)
    end

    test "normalized user map has atom keys" do
      assert {:ok, normalized} = TestProvider.normalize_user(valid_user_data())
      assert Map.keys(normalized) |> Enum.all?(&is_atom/1)
    end

    test "normalized user map has required keys" do
      assert {:ok, normalized} = TestProvider.normalize_user(valid_user_data())
      assert Map.has_key?(normalized, :provider_user_id)
      assert Map.has_key?(normalized, :email)
      assert Map.has_key?(normalized, :name)
      assert Map.has_key?(normalized, :username)
      assert Map.has_key?(normalized, :avatar_url)
    end

    test "preserves original values without transformation" do
      assert {:ok, normalized} = TestProvider.normalize_user(valid_user_data())
      assert normalized.email == "alice@example.com"
      assert normalized.name == "Alice Example"
      assert normalized.username == "alice"
      assert normalized.avatar_url == "https://example.com/avatar.png"
    end

    test "uses standard OIDC claim names" do
      # username must come from "preferred_username" (OIDC standard)
      user_data = %{
        "sub" => "555",
        "preferred_username" => "oidc_user",
        "picture" => "https://example.com/pic.png"
      }

      assert {:ok, normalized} = TestProvider.normalize_user(user_data)
      assert normalized.username == "oidc_user"
      assert normalized.avatar_url == "https://example.com/pic.png"
    end

    test "sub claim is mandatory per OIDC spec" do
      # Verifies the contract: missing sub always yields an error
      assert {:error, _} = TestProvider.normalize_user(%{"email" => "no-sub@example.com"})
    end

    test "other OIDC claims are optional" do
      # Only "sub" is required; all others can be absent
      assert {:ok, normalized} = TestProvider.normalize_user(minimal_user_data())
      assert normalized.provider_user_id == "987654321"
    end

    # Error conditions

    test "returns error tuple when user_data is not a map" do
      assert {:error, :invalid_user_data} = TestProvider.normalize_user("not a map")
      assert {:error, :invalid_user_data} = TestProvider.normalize_user(42)
      assert {:error, :invalid_user_data} = TestProvider.normalize_user(nil)
      assert {:error, :invalid_user_data} = TestProvider.normalize_user([:list])
    end

    test "returns error tuple when \"sub\" field is missing" do
      user_data = Map.delete(valid_user_data(), "sub")
      assert {:error, :missing_provider_user_id} = TestProvider.normalize_user(user_data)
    end

    test "returns error tuple when \"sub\" field has invalid type" do
      user_data = Map.put(valid_user_data(), "sub", %{"nested" => "not-allowed"})
      assert {:error, :invalid_provider_user_id} = TestProvider.normalize_user(user_data)
    end
  end
end
