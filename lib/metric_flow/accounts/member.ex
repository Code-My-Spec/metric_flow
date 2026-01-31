defmodule MetricFlow.Accounts.Member do
  @moduledoc """
  The Member schema manages the many-to-many relationship between accounts and users with role-based permissions.

  ## Role Hierarchy
  - `:owner` - Full control, can manage all aspects including deletion
  - `:admin` - Can manage users and settings but cannot delete account
  - `:member` - Basic access, cannot manage users or settings

  ## Business Rules
  - Each account must have at least one owner
  - Users can have different roles in different accounts
  - Personal accounts always have the user as owner
  - Users cannot have duplicate memberships in same account
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "members" do
    field :role, Ecto.Enum, values: [:owner, :admin, :member], default: :member

    belongs_to :user, MetricFlow.Users.User
    belongs_to :account, MetricFlow.Accounts.Account, type: :binary_id

    timestamps()
  end

  @doc """
  Creates a changeset for creating a new member.
  """
  def changeset(member, attrs) do
    member
    |> cast(attrs, [:role, :user_id, :account_id])
    |> validate_required([:role, :user_id, :account_id])
    |> validate_inclusion(:role, [:owner, :admin, :member])
    |> assoc_constraint(:user)
    |> assoc_constraint(:account)
    |> unique_constraint([:user_id, :account_id], name: :members_user_id_account_id_index)
  end

  @doc """
  Creates a changeset for updating a member's role.
  """
  def update_role_changeset(member, attrs) do
    member
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, [:owner, :admin, :member])
  end

  @doc """
  Validates that an account maintains at least one owner.
  """
  def validate_owner_exists(changeset, repo) do
    case get_field(changeset, :role) do
      :owner ->
        changeset

      _ ->
        user_id = get_field(changeset, :user_id)
        account_id = get_field(changeset, :account_id)

        if user_id && account_id do
          case repo.get_by(__MODULE__, user_id: user_id, account_id: account_id) do
            %{role: :owner} ->
              owner_count =
                repo.aggregate(
                  from(m in __MODULE__, where: m.account_id == ^account_id and m.role == :owner),
                  :count
                )

              if owner_count <= 1 do
                add_error(changeset, :role, "account must have at least one owner")
              else
                changeset
              end

            _ ->
              changeset
          end
        else
          changeset
        end
    end
  end

  @doc """
  Checks if a user has a specific role or higher in an account.
  """
  def has_role?(member, required_role) do
    role_hierarchy = %{
      member: 1,
      admin: 2,
      owner: 3
    }

    Map.get(role_hierarchy, member.role, 0) >= Map.get(role_hierarchy, required_role, 0)
  end

  @doc """
  Checks if a user is an owner of an account.
  """
  def owner?(member), do: member.role == :owner

  @doc """
  Checks if a user is an admin or owner of an account.
  """
  def admin_or_owner?(member), do: member.role in [:admin, :owner]
end
