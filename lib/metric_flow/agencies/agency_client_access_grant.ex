defmodule MetricFlow.Agencies.AgencyClientAccessGrant do
  @moduledoc """
  Ecto schema representing an agency's access grant to a client account.

  Stores the agency_account_id, client_account_id, access_level, and
  origination_status. The origination_status distinguishes whether the agency
  originated the client account (:originator) or was invited (:invited).
  Enforces a unique constraint on (agency_account_id, client_account_id) to
  ensure at most one grant per agency-client pair.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account

  @type t :: %__MODULE__{
          id: integer() | nil,
          agency_account_id: integer() | nil,
          client_account_id: integer() | nil,
          access_level: :read_only | :account_manager | :admin | nil,
          origination_status: :invited | :originator | nil,
          agency_account: Account.t() | Ecto.Association.NotLoaded.t(),
          client_account: Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @access_levels [:read_only, :account_manager, :admin]
  @origination_statuses [:invited, :originator]

  schema "agency_client_access_grants" do
    field :access_level, Ecto.Enum, values: @access_levels
    field :origination_status, Ecto.Enum, values: @origination_statuses, default: :invited

    belongs_to :agency_account, Account, foreign_key: :agency_account_id
    belongs_to :client_account, Account, foreign_key: :client_account_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating or updating an AgencyClientAccessGrant record.

  Validates required fields and enforces the unique constraint on
  (agency_account_id, client_account_id). Validates access_level is one of the
  permitted values.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:agency_account_id, :client_account_id, :access_level, :origination_status])
    |> validate_required([:agency_account_id, :client_account_id, :access_level])
    |> assoc_constraint(:agency_account)
    |> assoc_constraint(:client_account)
    |> unique_constraint(:agency_account_id,
      name: :agency_client_access_grants_agency_account_id_client_account_id
    )
  end

  @doc """
  Builds a changeset for updating only the origination_status on an existing grant.
  """
  @spec originator_changeset(t(), map()) :: Ecto.Changeset.t()
  def originator_changeset(grant, attrs) do
    grant
    |> cast(attrs, [:origination_status])
    |> validate_required([:origination_status])
  end
end
