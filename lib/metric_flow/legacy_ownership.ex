defmodule MetricFlow.LegacyOwnership do
  @moduledoc """
  Finishes the move of data ownership from users to accounts
  (migration `MoveDataOwnershipToAccounts`).

  The migration backfilled `account_id` for every user who originated exactly
  one account. Rows of users with zero or several originated accounts were
  left with a NULL `account_id` -- invisible to every account-scoped query --
  because guessing their account could expose one client's data to another.

    * `report/0` lists those users, their candidate accounts and how many
      unassigned rows they have per table.
    * `assign/2` moves one user's unassigned rows into an account they are a
      member of.

  Both are exposed for operators through `MetricFlow.Release`.
  """

  import Ecto.Query

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo
  alias MetricFlow.Users.User

  @tables ~w(integrations sync_jobs sync_history metrics derived_metric_definitions dashboards visualizations)

  @doc "Tables whose rows are account-owned and may still lack an account."
  @spec tables() :: [String.t()]
  def tables, do: @tables

  @doc """
  Users who still own rows with no account, with their candidate accounts.

  Returns a list of maps:

      %{
        user_id: 12,
        email: "a@example.com",
        originated_account_count: 2,
        candidate_accounts: [%{id: 3, name: "Acme", type: :client, role: :owner, originated: true}],
        row_counts: %{"metrics" => 1200, "integrations" => 2, ...}
      }
  """
  @spec report() :: [map()]
  def report do
    counts = unassigned_counts_by_user()

    users =
      from(u in User, where: u.id in ^Map.keys(counts), order_by: u.id)
      |> Repo.all()

    Enum.map(users, fn user ->
      candidates = candidate_accounts(user.id)

      %{
        user_id: user.id,
        email: user.email,
        originated_account_count: Enum.count(candidates, & &1.originated),
        candidate_accounts: candidates,
        row_counts: Map.fetch!(counts, user.id)
      }
    end)
  end

  @doc """
  Moves every row of `user_id` that has no account into `account_id`.

  The user must be a member of the account. An integration is skipped when
  the account already has a connection for that provider (one connection per
  provider per account); skipped providers are reported so an operator can
  decide which connection to keep.

  Returns `{:ok, %{table => updated_count, skipped_integrations: [provider]}}`.
  """
  @spec assign(integer(), integer()) ::
          {:ok, map()} | {:error, :not_a_member | :account_not_found | :user_not_found}
  def assign(user_id, account_id) when is_integer(user_id) and is_integer(account_id) do
    cond do
      is_nil(Repo.get(User, user_id)) ->
        {:error, :user_not_found}

      is_nil(Repo.get(Account, account_id)) ->
        {:error, :account_not_found}

      not Repo.exists?(
        from(m in AccountMember, where: m.user_id == ^user_id and m.account_id == ^account_id)
      ) ->
        {:error, :not_a_member}

      true ->
        Repo.transaction(fn -> do_assign(user_id, account_id) end)
    end
  end

  defp do_assign(user_id, account_id) do
    taken =
      from(i in "integrations", where: i.account_id == ^account_id, select: i.provider)
      |> Repo.all()

    skipped =
      from(i in "integrations",
        where:
          i.user_id == ^user_id and is_nil(i.account_id) and
            i.provider in type(^taken, {:array, :string}),
        select: i.provider
      )
      |> Repo.all()

    {integrations, _} =
      from(i in "integrations",
        where:
          i.user_id == ^user_id and is_nil(i.account_id) and
            i.provider not in type(^taken, {:array, :string})
      )
      |> Repo.update_all(set: [account_id: account_id])

    # Sync rows follow their integration when it already belongs to an account.
    for table <- ["sync_jobs", "sync_history"] do
      from(t in table,
        join: i in "integrations",
        on: i.id == t.integration_id,
        where: t.user_id == ^user_id and is_nil(t.account_id) and not is_nil(i.account_id),
        update: [set: [account_id: i.account_id]]
      )
      |> Repo.update_all([])
    end

    counts =
      for table <- @tables -- ["integrations"], into: %{} do
        {count, _} =
          from(t in table, where: t.user_id == ^user_id and is_nil(t.account_id))
          |> Repo.update_all(set: [account_id: account_id])

        {table, count}
      end

    counts
    |> Map.put("integrations", integrations)
    |> Map.put(:skipped_integrations, skipped)
  end

  defp unassigned_counts_by_user do
    Enum.reduce(@tables, %{}, fn table, acc ->
      from(t in table,
        where: is_nil(t.account_id) and not is_nil(t.user_id),
        group_by: t.user_id,
        select: {t.user_id, count()}
      )
      |> Repo.all()
      |> Enum.reduce(acc, fn {user_id, count}, acc ->
        acc
        |> Map.put_new(user_id, Map.new(@tables, &{&1, 0}))
        |> put_in([user_id, table], count)
      end)
    end)
  end

  defp candidate_accounts(user_id) do
    from(a in Account,
      left_join: m in AccountMember,
      on: m.account_id == a.id and m.user_id == ^user_id,
      where: not is_nil(m.id) or a.originator_user_id == ^user_id,
      order_by: [asc: a.id],
      select: %{
        id: a.id,
        name: a.name,
        type: a.type,
        role: m.role,
        originated: a.originator_user_id == ^user_id
      }
    )
    |> Repo.all()
  end
end
