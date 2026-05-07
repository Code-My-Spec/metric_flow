defmodule MetricFlow.Agencies.WhiteLabelConfig do
  @moduledoc """
  Ecto schema for agency white-label branding configuration.

  Stores logo URL, primary and secondary brand colors, and custom subdomain.
  Enforces unique subdomain constraint. Validates hex color format (#RRGGBB)
  and subdomain format (lowercase letters, numbers, hyphens only, 3-63 chars).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account

  @type t :: %__MODULE__{
          id: integer() | nil,
          agency_id: integer() | nil,
          logo_url: String.t() | nil,
          primary_color: String.t() | nil,
          secondary_color: String.t() | nil,
          subdomain: String.t() | nil,
          custom_domain: String.t() | nil,
          custom_css: String.t() | nil,
          custom_domain_verified_at: DateTime.t() | nil,
          subdomain_verified_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "white_label_configs" do
    field :logo_url, :string
    field :primary_color, :string
    field :secondary_color, :string
    field :subdomain, :string
    field :custom_domain, :string
    field :custom_css, :string
    field :custom_domain_verified_at, :utc_datetime
    field :subdomain_verified_at, :utc_datetime

    belongs_to :agency, Account, foreign_key: :agency_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a WhiteLabelConfig record.

  Validates subdomain format and uniqueness, validates hex color formats, and
  ensures association with an agency account.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(white_label_config, attrs) do
    white_label_config
    |> cast(attrs, [:agency_id, :logo_url, :primary_color, :secondary_color, :subdomain, :custom_domain, :custom_css])
    |> validate_required([:agency_id, :subdomain])
    |> validate_format(:subdomain, ~r/^[a-z0-9-]+$/, message: "must contain only lowercase letters, numbers, and hyphens")
    |> validate_length(:subdomain, min: 3, max: 63)
    |> validate_custom_domain()
    |> validate_hex_color(:primary_color)
    |> validate_hex_color(:secondary_color)
    |> validate_length(:logo_url, max: 500)
    |> assoc_constraint(:agency)
    |> unique_constraint(:subdomain)
    |> unique_constraint(:custom_domain)
  end

  @doc """
  Changeset for updating DNS verification timestamps only.

  These fields are not user-settable — they are updated by the DNS
  verification process.
  """
  @spec dns_verification_changeset(t(), map()) :: Ecto.Changeset.t()
  def dns_verification_changeset(white_label_config, attrs) do
    white_label_config
    |> cast(attrs, [:custom_domain_verified_at, :subdomain_verified_at])
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_custom_domain(changeset) do
    changeset
    |> validate_format(:custom_domain, ~r/^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$/,
      message: "must be a valid hostname (e.g., analytics.yourdomain.com)"
    )
    |> validate_length(:custom_domain, max: 253)
    |> validate_change(:custom_domain, fn :custom_domain, domain ->
      if String.ends_with?(domain, ".metric-flow.app") do
        [custom_domain: "cannot be a metric-flow.app subdomain — use the Subdomain field instead"]
      else
        []
      end
    end)
  end

  defp validate_hex_color(changeset, field) do
    validate_change(changeset, field, fn field, value ->
      case Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, value) do
        true -> []
        false -> [{field, "is invalid — must be a hex color in #RRGGBB format"}]
      end
    end)
  end
end
