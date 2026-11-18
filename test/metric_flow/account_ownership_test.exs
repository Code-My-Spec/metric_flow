defmodule MetricFlow.AccountOwnershipTest do
  @moduledoc """
  Integrations, metrics, sync history and dashboards belong to an account:
  whoever connects them, every member of the account sees them, and only
  owners, admins and account managers change them.
  """

  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AgenciesFixtures, only: [account_fixture: 1]

  alias MetricFlow.AccountAccess
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies
  alias MetricFlow.Dashboards
  alias MetricFlow.DataSync
  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.IntegrationRepository
  alias MetricFlow.LegacyOwnership
  alias MetricFlow.Metrics
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  defp member!(account, user, role) do
    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert!()

    user
  end

  defp scope_in(user, account), do: Scope.put_account_id(Scope.for_user(user), account.id)

  defp token_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        access_token: "token-#{System.unique_integer([:positive])}",
        refresh_token: "refresh-#{System.unique_integer([:positive])}",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        granted_scopes: ["https://www.googleapis.com/auth/adwords"],
        provider_metadata: %{"email" => "ads@example.com"}
      },
      overrides
    )
  end

  defp metric_attrs(name, value) do
    %{
      metric_type: "advertising",
      metric_name: name,
      normalized_metric_name: name,
      value: value,
      recorded_at: DateTime.add(DateTime.utc_now(), -86_400, :second),
      provider: :google_ads,
      dimensions: %{}
    }
  end

  setup do
    client = account_fixture(%{type: "client"})
    owner = member!(client, user_fixture(), :owner)
    %{client: client, owner: owner}
  end

  describe "members share the account's data" do
    test "an integration connected by one member is visible to every member", %{
      client: client,
      owner: owner
    } do
      teammate = member!(client, user_fixture(), :member)

      assert {:ok, integration} =
               IntegrationRepository.upsert_integration(
                 scope_in(owner, client),
                 :google,
                 token_attrs()
               )

      assert integration.account_id == client.id
      assert integration.user_id == owner.id

      assert [%Integration{id: id}] = Integrations.list_integrations(scope_in(teammate, client))
      assert id == integration.id
      assert Integrations.connected?(scope_in(teammate, client), :google)
    end

    test "synced metrics are read by every member and not by other accounts", %{
      client: client,
      owner: owner
    } do
      teammate = member!(client, user_fixture(), :read_only)
      outsider = user_fixture()
      other_account = account_fixture(%{type: "client"})
      member!(other_account, outsider, :owner)

      assert {:ok, 1} =
               Metrics.create_metrics(Scope.for_account(client.id), [metric_attrs("clicks", 7.0)])

      assert [%{metric_name: "clicks", account_id: account_id}] =
               Metrics.list_metrics(scope_in(teammate, client))

      assert account_id == client.id
      assert [_] = Metrics.list_metrics(scope_in(owner, client))
      assert Metrics.list_metrics(scope_in(outsider, other_account)) == []
    end

    test "a scope naming an account the user is not a member of sees nothing", %{
      client: client,
      owner: owner
    } do
      IntegrationRepository.upsert_integration(
        scope_in(owner, client),
        :google,
        token_attrs()
      )

      Metrics.create_metrics(Scope.for_account(client.id), [metric_attrs("clicks", 1.0)])
      outsider = user_fixture()

      assert Integrations.list_integrations(scope_in(outsider, client)) == []
      assert Metrics.list_metrics(scope_in(outsider, client)) == []

      assert {:error, :not_found} =
               Integrations.get_integration(scope_in(outsider, client), :google)
    end

    test "dashboards created by one member belong to the account", %{client: client, owner: owner} do
      teammate = member!(client, user_fixture(), :admin)

      assert {:ok, dashboard} = Dashboards.save_dashboard(scope_in(owner, client), %{name: "Q4"})
      assert dashboard.account_id == client.id

      assert [%{id: id}] = Dashboards.list_dashboards(scope_in(teammate, client))
      assert id == dashboard.id
    end
  end

  describe "agency members acting in a client account" do
    setup %{client: client} do
      agency = account_fixture(%{type: "agency"})
      agency_admin = member!(agency, user_fixture(), :admin)
      %{agency: agency, agency_admin: agency_admin, client: client}
    end

    test "see and edit the client's integrations through an account_manager grant", %{
      agency: agency,
      agency_admin: agency_admin,
      client: client,
      owner: owner
    } do
      {:ok, _} =
        IntegrationRepository.upsert_integration(
          scope_in(owner, client),
          :google,
          token_attrs()
        )

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(
                 Scope.for_user(agency_admin),
                 agency.id,
                 client.id,
                 :account_manager,
                 false
               )

      scope = scope_in(agency_admin, client)

      assert [%Integration{provider: :google}] = Integrations.list_integrations(scope)

      assert {:ok, updated} =
               Integrations.update_provider_metadata(scope, :google, %{
                 "customer_id" => "123"
               })

      assert updated.provider_metadata["customer_id"] == "123"
      assert {:ok, _job} = DataSync.sync_integration(scope, :google)

      # The client's owner sees the agency's change.
      {:ok, seen} = Integrations.get_integration(scope_in(owner, client), :google)
      assert seen.provider_metadata["customer_id"] == "123"
    end

    test "connecting while acting in the client account stores the connection on the client", %{
      agency: agency,
      agency_admin: agency_admin,
      client: client,
      owner: owner
    } do
      {:ok, _} =
        Agencies.grant_client_account_access(
          Scope.for_user(agency_admin),
          agency.id,
          client.id,
          :admin,
          false
        )

      assert {:ok, integration} =
               IntegrationRepository.upsert_integration(
                 scope_in(agency_admin, client),
                 :facebook_ads,
                 token_attrs()
               )

      assert integration.account_id == client.id
      assert [_] = Integrations.list_integrations(scope_in(owner, client))
      assert Integrations.list_integrations(scope_in(agency_admin, agency)) == []
    end
  end

  describe "read_only members" do
    setup %{client: client, owner: owner} do
      {:ok, _} =
        IntegrationRepository.upsert_integration(
          scope_in(owner, client),
          :google,
          token_attrs()
        )

      viewer = member!(client, user_fixture(), :read_only)
      %{viewer: viewer}
    end

    test "can read but not change the account's integrations", %{
      client: client,
      viewer: viewer
    } do
      scope = scope_in(viewer, client)

      assert [_] = Integrations.list_integrations(scope)

      assert {:error, :unauthorized} =
               Integrations.update_provider_metadata(scope, :google, %{"customer_id" => "1"})

      assert {:error, :unauthorized} = Integrations.disconnect(scope, :google)
      assert {:error, :unauthorized} = Integrations.delete_integration(scope, :google)

      assert {:error, :unauthorized} =
               IntegrationRepository.upsert_integration(scope, :quickbooks, token_attrs())

      assert {:error, :unauthorized} = DataSync.sync_integration(scope, :google)
      refute AccountAccess.can_write?(scope)
      assert [_] = Integrations.list_integrations(scope)
    end

    test "cannot add derived metric definitions", %{client: client, viewer: viewer} do
      assert {:error, :unauthorized} =
               Metrics.create_derived_metric_definition(scope_in(viewer, client), %{
                 "name" => "CPA",
                 "numerator" => "spend",
                 "denominator" => "conversions"
               })
    end
  end

  describe "one connection per provider per account" do
    test "a second member reconnecting replaces tokens and keeps selections", %{
      client: client,
      owner: owner
    } do
      admin = member!(client, user_fixture(), :admin)

      {:ok, first} =
        IntegrationRepository.upsert_integration(
          scope_in(owner, client),
          :google,
          token_attrs()
        )

      {:ok, _} =
        Integrations.update_provider_metadata(scope_in(owner, client), :google, %{
          "customer_id" => "555"
        })

      {:ok, second} =
        IntegrationRepository.upsert_integration(
          scope_in(admin, client),
          :google,
          token_attrs(%{access_token: "fresh-token", provider_metadata: %{"email" => "b@x.com"}})
        )

      assert second.id == first.id

      assert Repo.aggregate(from(i in Integration, where: i.account_id == ^client.id), :count) ==
               1

      {:ok, stored} = Integrations.get_integration(scope_in(owner, client), :google)
      assert stored.access_token == "fresh-token"
      assert stored.provider_metadata["customer_id"] == "555"
      assert stored.provider_metadata["email"] == "b@x.com"
    end

    test "the database rejects a second row for the same account and provider", %{
      client: client,
      owner: owner
    } do
      attrs = Map.merge(token_attrs(), %{provider: :google})

      {:ok, _} =
        %Integration{account_id: client.id, user_id: owner.id}
        |> Integration.changeset(attrs)
        |> Repo.insert()

      other = member!(client, user_fixture(), :admin)

      assert {:error, changeset} =
               %Integration{account_id: client.id, user_id: other.id}
               |> Integration.changeset(attrs)
               |> Repo.insert()

      assert %{account_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "different accounts can each connect the same provider", %{client: client, owner: owner} do
      other_account = account_fixture(%{type: "client"})
      member!(other_account, owner, :owner)

      assert {:ok, a} =
               IntegrationRepository.upsert_integration(
                 scope_in(owner, client),
                 :google,
                 token_attrs()
               )

      assert {:ok, b} =
               IntegrationRepository.upsert_integration(
                 scope_in(owner, other_account),
                 :google,
                 token_attrs()
               )

      refute a.id == b.id
    end
  end

  describe "legacy ownership report and assignment" do
    defp legacy_metric!(user_id) do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      Repo.insert_all("metrics", [
        %{
          user_id: user_id,
          account_id: nil,
          metric_type: "traffic",
          metric_name: "sessions",
          value: 1.0,
          recorded_at: now,
          provider: "google_analytics",
          dimensions: %{},
          inserted_at: now,
          updated_at: now
        }
      ])
    end

    defp legacy_integration!(user_id, provider) do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      {1, [%{id: id}]} =
        Repo.insert_all(
          "integrations",
          [
            %{
              user_id: user_id,
              account_id: nil,
              provider: provider,
              access_token: MetricFlow.Vault.encrypt!("legacy-token"),
              expires_at: now,
              granted_scopes: [],
              provider_metadata: %{},
              inserted_at: now,
              updated_at: now
            }
          ],
          returning: [:id]
        )

      id
    end

    test "lists users whose rows have no account, with candidates and counts" do
      user = user_fixture()
      a = account_fixture(%{type: "client", originator_user_id: user.id, name: "First"})
      b = account_fixture(%{type: "agency", originator_user_id: user.id, name: "Second"})
      member!(a, user, :owner)
      member!(b, user, :owner)
      legacy_metric!(user.id)
      legacy_metric!(user.id)
      legacy_integration!(user.id, "google")

      assert [entry] = Enum.filter(LegacyOwnership.report(), &(&1.user_id == user.id))
      assert entry.email == user.email
      assert entry.originated_account_count == 2
      assert entry.row_counts["metrics"] == 2
      assert entry.row_counts["integrations"] == 1
      assert entry.row_counts["dashboards"] == 0

      assert Enum.map(entry.candidate_accounts, &{&1.id, &1.name, &1.type, &1.role}) == [
               {a.id, "First", :client, :owner},
               {b.id, "Second", :agency, :owner}
             ]
    end

    test "a user with no originated account is reported with the accounts they belong to", %{
      client: client
    } do
      invited = member!(client, user_fixture(), :member)
      legacy_metric!(invited.id)

      assert [entry] = Enum.filter(LegacyOwnership.report(), &(&1.user_id == invited.id))
      assert entry.originated_account_count == 0
      assert [%{id: id, originated: false, role: :member}] = entry.candidate_accounts
      assert id == client.id
    end

    test "assign moves the user's unassigned rows into the chosen account", %{
      client: client,
      owner: owner
    } do
      legacy_metric!(owner.id)
      legacy_integration!(owner.id, "facebook_ads")

      assert {:ok, result} = LegacyOwnership.assign(owner.id, client.id)
      assert result["metrics"] == 1
      assert result["integrations"] == 1
      assert result.skipped_integrations == []

      assert [_] = Metrics.list_metrics(scope_in(owner, client))

      assert [%{provider: :facebook_ads}] =
               Integrations.list_integrations(scope_in(owner, client))

      refute Enum.any?(LegacyOwnership.report(), &(&1.user_id == owner.id))
    end

    test "assign keeps the account's existing connection when providers collide", %{
      client: client,
      owner: owner
    } do
      {:ok, existing} =
        IntegrationRepository.upsert_integration(
          scope_in(owner, client),
          :google,
          token_attrs()
        )

      legacy_id = legacy_integration!(owner.id, "google")

      assert {:ok, %{skipped_integrations: ["google"]}} =
               LegacyOwnership.assign(owner.id, client.id)

      assert [%{id: id}] = Integrations.list_integrations(scope_in(owner, client))
      assert id == existing.id
      assert %{account_id: nil} = Repo.get!(Integration, legacy_id)
    end

    test "assign refuses an account the user is not a member of", %{client: client} do
      stranger = user_fixture()
      legacy_metric!(stranger.id)

      assert {:error, :not_a_member} = LegacyOwnership.assign(stranger.id, client.id)
    end
  end

  describe "active account resolution" do
    test "defaults to the switched-to account, else an originated one", %{
      client: client,
      owner: owner
    } do
      own = account_fixture(%{type: "client", originator_user_id: owner.id})
      member!(own, owner, :owner)

      assert AccountAccess.default_account_id(owner.id) == own.id

      MetricFlow.Accounts.touch_membership(Scope.for_user(owner), client.id)
      assert AccountAccess.default_account_id(owner.id) == client.id
    end
  end
end
