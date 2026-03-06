defmodule MetricFlow.Accounts.AccountMember do
  @moduledoc """
  Ecto schema representing the membership join between a user and an account.

  Stores account_id, user_id, and role. The role field uses an Ecto.Enum with
  values :owner, :admin, :account_manager, :read_only, and :member (a legacy
  alias for read_only). Provides a changeset validating presence of all required
  fields and inclusion of role in the valid enum set. The user association is
  preloaded by AccountRepository when returning member lists.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: integer() | nil,
          user_id: integer() | nil,
          role: :owner | :admin | :account_manager | :read_only | :member | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "account_members" do
    field :role, Ecto.Enum, values: [:owner, :admin, :account_manager, :read_only, :member]

    belongs_to :account, Account
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating a new account membership.

  Casts account_id, user_id, and role. Validates all fields are present and
  that role is a valid enum value. Adds a unique constraint on the
  {account_id, user_id} pair to prevent duplicate memberships.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(account_member, attrs) do
    account_member
    |> cast(attrs, [:account_id, :user_id, :role])
    |> validate_required([:account_id, :user_id, :role])
    |> unique_constraint(:account_id, name: :account_members_account_id_user_id_index)
    |> foreign_key_constraint(:account_id, name: :account_members_account_id_fkey)
    |> foreign_key_constraint(:user_id, name: :account_members_user_id_fkey)
  end

  @doc """
  Builds a changeset for updating only the role on an existing account membership.

  Used by AccountRepository when reassigning a member's role. Casts and validates
  only the role field. Role must be explicitly provided in attrs — the existing
  value on the struct is not accepted as satisfying the requirement.
  """
  @spec role_changeset(t(), map()) :: Ecto.Changeset.t()
  def role_changeset(account_member, attrs) do
    account_member
    |> change()
    |> force_change(:role, nil)
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end
end
