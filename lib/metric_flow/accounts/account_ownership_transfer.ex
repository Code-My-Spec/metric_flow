defmodule MetricFlow.Accounts.AccountOwnershipTransfer do
  @moduledoc """
  Ecto schema representing a pending or confirmed ownership transfer.

  Created when an owner initiates a transfer to either an existing member
  with account access or a new email address. Carries a hashed token (the
  raw token is emailed to the recipient and never stored) — confirming the
  transfer via that token is what actually re-assigns the :owner role, not
  the initiating request itself.

  `initiated_by_email` and `target_email` are denormalized at creation time
  so the completed-transfer log entry on the settings page can render both
  parties without depending on a user record that may later change.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Users.User

  @hash_algorithm :sha256
  @rand_size 32

  @type t :: %__MODULE__{
          id: integer() | nil,
          token: String.t() | nil,
          token_hash: binary() | nil,
          account_id: integer() | nil,
          initiated_by_user_id: integer() | nil,
          initiated_by_email: String.t() | nil,
          target_user_id: integer() | nil,
          target_email: String.t() | nil,
          status: :pending | :confirmed | nil,
          remain_admin: boolean(),
          make_copy: boolean(),
          transfer_originator: boolean(),
          confirmed_at: DateTime.t() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          initiated_by: User.t() | Ecto.Association.NotLoaded.t(),
          target_user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "account_ownership_transfers" do
    field :token, :string, virtual: true
    field :token_hash, :binary
    field :initiated_by_email, :string
    field :target_email, :string
    field :status, Ecto.Enum, values: [:pending, :confirmed], default: :pending
    field :remain_admin, :boolean, default: false
    field :make_copy, :boolean, default: false
    field :transfer_originator, :boolean, default: false
    field :confirmed_at, :utc_datetime

    belongs_to :account, Account
    belongs_to :initiated_by, User, foreign_key: :initiated_by_user_id
    belongs_to :target_user, User, foreign_key: :target_user_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating a new pending ownership transfer.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(transfer, attrs) do
    transfer
    |> cast(attrs, [
      :token_hash,
      :account_id,
      :initiated_by_user_id,
      :initiated_by_email,
      :target_user_id,
      :target_email,
      :remain_admin,
      :make_copy,
      :transfer_originator
    ])
    |> validate_required([:token_hash, :account_id, :target_email])
    |> validate_format(:target_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email address"
    )
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:token_hash)
  end

  @doc """
  Builds a changeset marking a pending transfer as confirmed.
  """
  @spec confirm_changeset(t()) :: Ecto.Changeset.t()
  def confirm_changeset(%__MODULE__{} = transfer) do
    transfer
    |> change(status: :confirmed, confirmed_at: DateTime.utc_now(:second))
    |> validate_required([:status])
  end

  @doc """
  Generates a cryptographically secure token and returns a
  `{encoded_token, changeset}` pair, mirroring `Invitation.build_token/1`.
  """
  @spec build_token(t()) :: {String.t(), Ecto.Changeset.t()}
  def build_token(%__MODULE__{} = transfer) do
    raw_token = :crypto.strong_rand_bytes(@rand_size)
    encoded_token = Base.url_encode64(raw_token, padding: false)
    hashed = :crypto.hash(@hash_algorithm, raw_token)
    changeset = change(transfer, token_hash: hashed)
    {encoded_token, changeset}
  end

  @doc """
  Returns the SHA-256 hash of the given URL-safe base64-encoded raw token.
  """
  @spec token_hash(String.t()) :: binary()
  def token_hash(encoded_token) when is_binary(encoded_token) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, raw} -> :crypto.hash(@hash_algorithm, raw)
      :error -> :crypto.hash(@hash_algorithm, encoded_token)
    end
  end
end
