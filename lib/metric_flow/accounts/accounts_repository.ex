defmodule MetricFlow.Accounts.AccountsRepository do
  @moduledoc """
  Data access layer for account entities, handling personal and team account creation,
  basic account operations, and query building within the multi-tenant architecture.
  """

  import Ecto.Query, warn: false
  alias MetricFlow.Repo
  alias MetricFlow.Accounts.{Account, Member}
  alias MetricFlow.Users.User

  ## Basic CRUD Operations

  def create_account(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  def get_account(id) do
    Repo.get(Account, id)
  end

  def get_account!(id) do
    Repo.get!(Account, id)
  end

  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  def delete_account(%Account{} = account) do
    Repo.delete(account)
  end

  ## Account Type Management
  def create_personal_account(user_id) do
    user = Repo.get!(User, user_id)
    name = extract_name_from_email(user.email)

    attrs = %{
      name: name,
      slug: String.downcase(name) |> String.replace(~r/[^a-z0-9]/, "-")
    }

    Repo.transaction(fn ->
      with {:ok, account} <- create_account_with_type(attrs, :personal),
           {:ok, _member} <-
             create_member(%{user_id: user_id, account_id: account.id, role: :owner}) do
        account
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def create_team_account(attrs, creator_id) do
    Repo.transaction(fn ->
      with {:ok, account} <- create_account_with_type(attrs, :team),
           {:ok, _member} <-
             create_member(%{user_id: creator_id, account_id: account.id, role: :owner}) do
        account
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def get_personal_account(user_id) do
    from(a in Account,
      join: m in Member,
      on: m.account_id == a.id,
      where: m.user_id == ^user_id and a.type == :personal
    )
    |> Repo.one()
  end

  def ensure_personal_account(user_id) do
    case get_personal_account(user_id) do
      nil ->
        {:ok, account} = create_personal_account(user_id)
        account

      account ->
        account
    end
  end

  ## Query Builders

  def by_slug(slug) do
    from(a in Account, where: a.slug == ^slug)
  end

  def by_type(type) do
    from(a in Account, where: a.type == ^type)
  end

  def with_preloads(preloads) do
    from(a in Account, preload: ^preloads)
  end

  ## Helper Functions

  defp create_account_with_type(attrs, type) do
    %Account{}
    |> Account.changeset(attrs)
    |> Ecto.Changeset.put_change(:type, type)
    |> Repo.insert()
  end

  defp create_member(attrs) do
    %Member{}
    |> Member.changeset(attrs)
    |> Repo.insert()
  end

  defp extract_name_from_email(email) do
    email
    |> String.split("@")
    |> List.first()
  end
end
