defmodule MetricFlow.DataSync.SyncJob do
  @moduledoc """
  Ecto schema representing scheduled or running sync jobs.

  Stores user_id, integration_id, provider, status (pending, running, completed,
  failed, cancelled), started_at, and completed_at timestamps. Belongs to User
  and Integration. Provides status transition functions and running time
  calculations.

  Status transitions:
  - :pending  -> :running   (job starts executing)
  - :running  -> :completed (job finishes successfully)
  - :running  -> :failed    (job encounters an error)
  - :running  -> :cancelled (job is cancelled mid-run)
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          integration_id: integer() | nil,
          provider: atom() | nil,
          status: atom() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          error_message: String.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          integration: Integration.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @providers [:google, :google_analytics, :google_ads, :google_search_console, :google_business, :google_business_reviews, :facebook_ads, :quickbooks]
  @statuses [:pending, :running, :completed, :failed, :cancelled]

  schema "sync_jobs" do
    field :provider, Ecto.Enum, values: @providers
    field :status, Ecto.Enum, values: @statuses
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :error_message, :string

    belongs_to :user, User
    belongs_to :integration, Integration

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a SyncJob record.

  Validates all required fields, type constraints, and associations. Enforces
  association constraints on user and integration to ensure referenced records
  exist in the database.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(sync_job, attrs) do
    sync_job
    |> cast(attrs, [
      :user_id,
      :integration_id,
      :provider,
      :status,
      :started_at,
      :completed_at,
      :error_message
    ])
    |> validate_required([:user_id, :integration_id, :provider, :status])
    |> assoc_constraint(:user)
    |> assoc_constraint(:integration)
  end

  @doc """
  Checks if the sync job is currently in running state.

  Returns true when status is :running, false for any other status.
  """
  @spec running?(t()) :: boolean()
  def running?(%__MODULE__{status: :running}), do: true
  def running?(%__MODULE__{}), do: false

  @doc """
  Checks if the sync job has finished execution successfully.

  Returns true when status is :completed, false for any other status.
  """
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{status: :completed}), do: true
  def completed?(%__MODULE__{}), do: false

  @doc """
  Calculates the duration of the sync job execution in seconds.

  Returns the time between started_at and completed_at for finished jobs, or
  the time between started_at and current UTC time for running jobs.
  Returns nil when started_at is not set (job has not started).
  """
  @spec running_time(t()) :: integer() | nil
  def running_time(%__MODULE__{started_at: nil}), do: nil

  def running_time(%__MODULE__{started_at: started_at, completed_at: completed_at}) do
    end_time = completed_at || DateTime.utc_now()
    DateTime.diff(end_time, started_at, :second)
  end
end
