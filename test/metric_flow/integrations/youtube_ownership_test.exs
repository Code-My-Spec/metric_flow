defmodule MetricFlow.Integrations.YouTubeOwnershipTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  alias MetricFlow.Accounts
  alias MetricFlow.Integrations.IntegrationRepository
  alias MetricFlow.Users.Scope

  defp account(scope) do
    {:ok, account} =
      Accounts.create_team_account(scope, %{
        name: "YouTube account",
        slug: "youtube-#{System.unique_integer([:positive])}"
      })

    account
  end

  defp credentials do
    %{
      access_token: "test-access",
      refresh_token: "test-refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 3600),
      granted_scopes: [],
      provider_metadata: %{"channel_ids" => ["channel-one"]}
    }
  end

  test "connections are isolated by account even for the same user" do
    user = user_fixture()
    scope = Scope.for_user(user)
    first = account(scope)
    second = account(scope)
    first_scope = Scope.put_account_id(scope, first.id)
    second_scope = Scope.put_account_id(scope, second.id)

    assert {:ok, connection} =
             IntegrationRepository.upsert_integration(first_scope, :youtube, credentials())

    assert connection.account_id == first.id
    assert {:error, :not_found} = IntegrationRepository.get_integration(second_scope, :youtube)
    refute IntegrationRepository.connected?(second_scope, :youtube)
    assert [] = IntegrationRepository.list_integrations(second_scope)

    assert {:ok, other} =
             IntegrationRepository.upsert_integration(second_scope, :youtube, credentials())

    refute other.id == connection.id

    stranger = Scope.for_user(user_fixture()) |> Scope.put_account_id(first.id)
    assert {:error, :not_found} = IntegrationRepository.get_integration(stranger, :youtube)

    assert {:error, :unauthorized} =
             IntegrationRepository.upsert_integration(stranger, :youtube, credentials())

    assert {:error, :unauthorized} = IntegrationRepository.delete_integration(stranger, :youtube)
  end

  test "read-only members cannot change connections and managers cannot transfer ownership" do
    owner = user_fixture()
    owner_scope = Scope.for_user(owner)
    client = account(owner_scope)
    owner_scope = Scope.put_account_id(owner_scope, client.id)
    reader = user_fixture()
    manager = user_fixture()
    assert {:ok, _} = Accounts.add_user_to_account(owner_scope, reader.id, client.id, :read_only)

    assert {:ok, _} =
             Accounts.add_user_to_account(owner_scope, manager.id, client.id, :account_manager)

    reader_scope = Scope.for_user(reader) |> Scope.put_account_id(client.id)
    manager_scope = Scope.for_user(manager) |> Scope.put_account_id(client.id)

    assert {:ok, original} =
             IntegrationRepository.upsert_integration(owner_scope, :youtube, credentials())

    assert {:ok, _} = IntegrationRepository.get_integration(reader_scope, :youtube)

    assert {:error, :unauthorized} =
             IntegrationRepository.update_integration(reader_scope, :youtube, credentials())

    assert {:error, :unauthorized} =
             IntegrationRepository.delete_integration(reader_scope, :youtube)

    attrs = Map.merge(credentials(), %{user_id: manager.id, account_id: -1, provider: :google})

    assert {:ok, updated} =
             IntegrationRepository.upsert_integration(manager_scope, :youtube, attrs)

    assert updated.id == original.id
    assert updated.user_id == owner.id
    assert updated.account_id == client.id
    assert updated.provider == :youtube

    assert {:ok, updated} =
             IntegrationRepository.update_integration(manager_scope, :youtube, attrs)

    assert updated.user_id == owner.id
    assert updated.account_id == client.id
    assert updated.provider == :youtube
  end

  test "rapid account switches preserve the last explicit selection" do
    scope = Scope.for_user(user_fixture())
    first = account(scope)
    second = account(scope)

    for selected <- [first, second, first, second, first] do
      assert :ok = Accounts.touch_membership(scope, selected.id)
      assert hd(Accounts.list_accounts(scope)).id == selected.id
      assert Accounts.most_recently_switched_account_id(scope) == selected.id
    end

    assert :ok = Accounts.touch_membership(scope, -1)
    assert hd(Accounts.list_accounts(scope)).id == first.id
  end
end
