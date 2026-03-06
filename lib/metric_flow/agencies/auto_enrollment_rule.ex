defmodule MetricFlow.Agencies.AutoEnrollmentRule do
  @moduledoc """
  Ecto schema representing domain-based auto-enrollment configuration for agency accounts.

  Stores email domain patterns, enabled status, and default access level for
  auto-enrolled users. Enforces one rule per agency per domain via unique constraint
  on [:agency_id, :email_domain]. Provides changeset validation for domain format
  and access level values.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account

  @type t :: %__MODULE__{
          id: integer() | nil,
          agency_id: integer() | nil,
          email_domain: String.t() | nil,
          default_access_level: :read_only | :account_manager | :admin | nil,
          enabled: boolean(),
          agency: Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @access_levels [:read_only, :account_manager, :admin]

  @domain_format ~r/^[a-z0-9]([a-z0-9\-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]*[a-z0-9])?)+$/

  schema "auto_enrollment_rules" do
    field :email_domain, :string
    field :default_access_level, Ecto.Enum, values: @access_levels
    field :enabled, :boolean, default: true

    belongs_to :agency, Account

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates an Ecto changeset for creating or updating an AutoEnrollmentRule record.

  Validates all required fields, type constraints, associations, and enforces
  unique constraint on the agency/domain combination to prevent duplicate rules.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:agency_id, :email_domain, :default_access_level, :enabled])
    |> validate_required([:agency_id, :email_domain, :default_access_level])
    |> validate_format(:email_domain, @domain_format, message: "must be a valid domain (e.g., example.com)")
    |> assoc_constraint(:agency)
    |> unique_constraint(:email_domain,
      name: :auto_enrollment_rules_agency_id_email_domain_index,
      message: "has already been taken"
    )
  end
end
