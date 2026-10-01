defmodule MetricFlow.Correlations.CorrelationGoalQueue do
  @moduledoc """
  Ecto schema for a goal metric waiting its turn to run.

  When a user selects multiple goal metrics at once, the first one runs
  immediately via the normal `CorrelationJob`/`CorrelationWorker` path; the
  rest are persisted here, one row per goal, in submission order. Only one
  correlation job can be in flight per account at a time, so
  `CorrelationWorker` pops and starts the next queued goal itself once the
  current job finishes (whether it completed or failed).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Accounts.Account

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: integer() | nil,
          goal_metric_name: String.t() | nil,
          time_window: atom() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @time_windows [:days_30, :days_90, :all_time]

  schema "correlation_goal_queue" do
    field :goal_metric_name, :string
    field :time_window, Ecto.Enum, values: @time_windows, default: :days_90

    belongs_to :account, Account

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:account_id, :goal_metric_name, :time_window])
    |> validate_required([:account_id, :goal_metric_name])
    |> validate_length(:goal_metric_name, max: 255)
    |> assoc_constraint(:account)
  end
end
