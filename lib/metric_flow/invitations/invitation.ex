defmodule MetricFlow.Invitations.Invitation do
  @moduledoc """
  Ecto schema representing an account access invitation.

  An invitation is created by an account owner or admin and sent to a recipient
  email address. It carries a hashed token (the raw token is sent to the
  invitee and never stored), the target role, a status (:pending or :accepted),
  and an expiry timestamp. Invitations expire after 7 days by default.

  Provides `build_token/1` for generating a `{encoded_token, changeset}` pair
  and `token_hash/1` for deterministically hashing a raw token for database
  lookup.

  The virtual `token` field is populated after insert when the encoded token is
  available (e.g. from `Invitations.create_invitation/1`). It is never stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Users.User

  @hash_algorithm :sha256
  @rand_size 32

  @type status :: :pending | :accepted | :declined
  @type role :: :owner | :admin | :account_manager | :read_only

  @type t :: %__MODULE__{
          id: integer() | nil,
          token: String.t() | nil,
          token_hash: binary() | nil,
          email: String.t() | nil,
          role: role() | nil,
          status: status() | nil,
          expires_at: DateTime.t() | nil,
          accepted_at: DateTime.t() | nil,
          account_id: integer() | nil,
          invited_by_user_id: integer() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          invited_by: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "invitations" do
    field :token, :string, virtual: true
    field :token_hash, :binary
    field :email, :string
    field :role, Ecto.Enum, values: [:owner, :admin, :account_manager, :read_only]
    field :status, Ecto.Enum, values: [:pending, :accepted, :declined], default: :pending
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime

    belongs_to :account, Account
    belongs_to :invited_by, User, foreign_key: :invited_by_user_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating a new invitation.

  Validates email format, role, and enforces the token_hash unique constraint.
  The `invited_by_user_id` is optional (system invites are permitted).
  Status defaults to `:pending` from the schema field definition.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [
      :token_hash,
      :email,
      :role,
      :expires_at,
      :account_id,
      :invited_by_user_id
    ])
    |> maybe_force_status(attrs)
    |> validate_required([:email, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email address"
    )
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:invited_by_user_id)
    |> unique_constraint(:token_hash)
  end

  @doc """
  Builds a changeset for marking an invitation as accepted.

  Sets status to `:accepted` and records the current UTC time in `accepted_at`.
  No additional attributes are required.
  """
  @spec accept_changeset(t()) :: Ecto.Changeset.t()
  def accept_changeset(%__MODULE__{} = invitation) do
    invitation
    |> change(status: :accepted, accepted_at: DateTime.utc_now(:second))
    |> validate_required([:status])
  end

  @doc """
  Generates a cryptographically secure token and returns a
  `{encoded_token, changeset}` pair.

  The encoded token is URL-safe base64. The changeset has the hashed token set
  and is ready to be merged with other invitation attributes.
  """
  @spec build_token(t()) :: {String.t(), Ecto.Changeset.t()}
  def build_token(%__MODULE__{} = invitation) do
    raw_token = :crypto.strong_rand_bytes(@rand_size)
    encoded_token = Base.url_encode64(raw_token, padding: false)
    hashed = :crypto.hash(@hash_algorithm, raw_token)
    changeset = change(invitation, token_hash: hashed)
    {encoded_token, changeset}
  end

  @doc """
  Returns the SHA-256 hash of the given URL-safe base64-encoded raw token.

  Used to look up invitations by the token included in the acceptance URL.
  """
  @spec token_hash(String.t()) :: binary()
  def token_hash(encoded_token) when is_binary(encoded_token) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, raw} -> :crypto.hash(@hash_algorithm, raw)
      :error -> :crypto.hash(@hash_algorithm, encoded_token)
    end
  end

  @doc """
  Builds a changeset for marking an invitation as declined.
  Sets status to `:declined`.
  """
  @spec decline_changeset(t()) :: Ecto.Changeset.t()
  def decline_changeset(%__MODULE__{} = invitation) do
    invitation
    |> change(status: :declined)
    |> validate_required([:status])
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp maybe_force_status(changeset, %{status: status}),
    do: force_change(changeset, :status, status)

  defp maybe_force_status(changeset, _attrs), do: changeset
end
