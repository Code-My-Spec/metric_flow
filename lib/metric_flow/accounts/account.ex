defmodule MetricFlow.Accounts.Account do
  @moduledoc """
  Ecto schema representing a business account.

  Stores account name, URL-friendly slug, account type (client or agency), and the
  originator_user_id tracking who created the account. The type field is read-only
  after creation. Client accounts are the default; agency accounts manage multiple
  client accounts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @account_types [:client, :agency]

  schema "accounts" do
    field :name, :string
    field :slug, :string
    field :type, Ecto.Enum, values: @account_types
    field :originator_user_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for updating an existing account's name and slug.
  Does not cast type or originator_user_id, as those fields are immutable after creation.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_length(:name, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> unique_constraint(:slug)
  end

  @doc """
  Builds a changeset for inserting a new account.
  Casts all required fields including type and originator_user_id.
  """
  @spec creation_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def creation_changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :slug, :type, :originator_user_id])
    |> validate_required([:name, :slug, :type, :originator_user_id])
    |> validate_length(:name, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> unique_constraint(:slug)
  end
end
