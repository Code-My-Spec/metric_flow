defmodule MetricFlow.Correlations.CorrelationJob do
  @moduledoc """
  Ecto schema representing a scheduled or completed correlation calculation run.

  Tracks the status of a background Oban job that computes Pearson correlations
  with time-lagged cross-correlation (TLCC) between all metrics and a selected
  goal metric. Belongs to Account.

  Status transitions:
  - :pending   -> :running   (job picked up by Oban worker)
  - :running   -> :completed (all correlations calculated successfully)
  - :running   -> :failed    (calculation error or timeout)
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Accounts.Account

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: integer() | nil,
          status: atom(),
          goal_metric_name: String.t() | nil,
          data_window_start: Date.t() | nil,
          data_window_end: Date.t() | nil,
          data_points: integer() | nil,
          results_count: integer() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          error_message: String.t() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @statuses [:pending, :running, :completed, :failed]

  schema "correlation_jobs" do
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :goal_metric_name, :string
    field :data_window_start, :date
    field :data_window_end, :date
    field :data_points, :integer
    field :results_count, :integer
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :error_message, :string

    belongs_to :account, Account

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(correlation_job, attrs) do
    correlation_job
    |> cast(attrs, [
      :account_id,
      :status,
      :goal_metric_name,
      :data_window_start,
      :data_window_end,
      :data_points,
      :results_count,
      :started_at,
      :completed_at,
      :error_message
    ])
    |> validate_required([:account_id, :status, :goal_metric_name])
    |> validate_length(:goal_metric_name, max: 255)
    |> validate_number(:data_points, greater_than_or_equal_to: 0)
    |> validate_number(:results_count, greater_than_or_equal_to: 0)
    |> assoc_constraint(:account)
  end

  @spec running?(t()) :: boolean()
  def running?(%__MODULE__{status: :running}), do: true
  def running?(%__MODULE__{}), do: false

  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{status: :completed}), do: true
  def completed?(%__MODULE__{}), do: false

  @spec duration(t()) :: integer() | nil
  def duration(%__MODULE__{started_at: nil}), do: nil

  def duration(%__MODULE__{started_at: started_at, completed_at: completed_at}) do
    end_time = completed_at || DateTime.utc_now()
    DateTime.diff(end_time, started_at, :second)
  end
end
