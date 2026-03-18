defmodule MetricFlow.DataSync.SyncHistory do
  @moduledoc """
  Ecto schema representing completed sync records with outcome tracking.

  Stores the result of a sync operation including the provider, final status
  (success, partial_success, failed), number of records synced, any error
  details, and start/completion timestamps. Belongs to a User, Integration,
  and SyncJob. Provides helper functions for checking success and computing
  elapsed duration.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          integration_id: integer() | nil,
          sync_job_id: integer() | nil,
          provider: atom() | nil,
          status: atom() | nil,
          records_synced: integer() | nil,
          error_message: String.t() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          integration: Integration.t() | Ecto.Association.NotLoaded.t(),
          sync_job: SyncJob.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @providers [:google, :google_analytics, :google_ads, :facebook_ads, :quickbooks]
  @statuses [:success, :partial_success, :failed]

  schema "sync_history" do
    field :provider, Ecto.Enum, values: @providers
    field :status, Ecto.Enum, values: @statuses
    field :records_synced, :integer
    field :error_message, :string
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    belongs_to :user, User
    belongs_to :integration, Integration
    belongs_to :sync_job, SyncJob

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a SyncHistory record.

  Validates all required fields, type constraints, associations, and ensures
  records_synced is non-negative. Enforces association constraints on user,
  integration, and sync_job to ensure referenced records exist in the database.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(sync_history, attrs) do
    sync_history
    |> cast(attrs, [
      :user_id,
      :integration_id,
      :sync_job_id,
      :provider,
      :status,
      :records_synced,
      :error_message,
      :started_at,
      :completed_at
    ])
    |> validate_required([
      :user_id,
      :integration_id,
      :sync_job_id,
      :provider,
      :status,
      :records_synced,
      :started_at,
      :completed_at
    ])
    |> validate_number(:records_synced, greater_than_or_equal_to: 0)
    |> assoc_constraint(:user)
    |> assoc_constraint(:integration)
    |> assoc_constraint(:sync_job)
  end

  @doc """
  Checks if the sync operation completed successfully.

  Returns true when status is :success, false for any other status.
  """
  @spec success?(t()) :: boolean()
  def success?(%__MODULE__{status: :success}), do: true
  def success?(%__MODULE__{}), do: false

  @doc """
  Calculates the duration of the sync operation in seconds.

  Returns the number of seconds elapsed between started_at and completed_at
  using DateTime.diff/2 with the :second unit.
  """
  @spec duration(t()) :: integer()
  def duration(%__MODULE__{started_at: started_at, completed_at: completed_at}) do
    DateTime.diff(completed_at, started_at, :second)
  end
end
