defmodule MetricFlow.Correlations.CorrelationResult do
  @moduledoc """
  Ecto schema storing a calculated Pearson correlation between a metric and a
  goal metric, including the automatically detected optimal time lag.

  The coefficient ranges from -1.0 (perfect anti-correlation) to 1.0 (perfect
  correlation). The optimal_lag indicates how many days the metric leads the
  goal metric (0-30). Only results with data_points >= 30 are persisted.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Correlations.CorrelationJob

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: integer() | nil,
          correlation_job_id: integer() | nil,
          metric_name: String.t() | nil,
          goal_metric_name: String.t() | nil,
          coefficient: float() | nil,
          optimal_lag: integer() | nil,
          data_points: integer() | nil,
          provider: atom() | nil,
          calculated_at: DateTime.t() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          correlation_job: CorrelationJob.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @providers [:google_analytics, :google_ads, :facebook_ads, :quickbooks]

  schema "correlation_results" do
    field :metric_name, :string
    field :goal_metric_name, :string
    field :coefficient, :float
    field :optimal_lag, :integer
    field :data_points, :integer
    field :provider, Ecto.Enum, values: @providers
    field :calculated_at, :utc_datetime_usec

    belongs_to :account, Account
    belongs_to :correlation_job, CorrelationJob

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(correlation_result, attrs) do
    correlation_result
    |> cast(attrs, [
      :account_id,
      :correlation_job_id,
      :metric_name,
      :goal_metric_name,
      :coefficient,
      :optimal_lag,
      :data_points,
      :provider,
      :calculated_at
    ])
    |> validate_required([
      :account_id,
      :correlation_job_id,
      :metric_name,
      :goal_metric_name,
      :coefficient,
      :optimal_lag,
      :data_points,
      :calculated_at
    ])
    |> validate_length(:metric_name, max: 255)
    |> validate_length(:goal_metric_name, max: 255)
    |> validate_number(:coefficient, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> validate_number(:optimal_lag, greater_than_or_equal_to: 0, less_than_or_equal_to: 30)
    |> validate_number(:data_points, greater_than_or_equal_to: 30)
    |> assoc_constraint(:account)
    |> assoc_constraint(:correlation_job)
    |> unique_constraint([:account_id, :correlation_job_id, :metric_name, :goal_metric_name],
      name: :correlation_results_account_id_correlation_job_id_metric_name_g
    )
  end

  @spec strong?(t()) :: boolean()
  def strong?(%__MODULE__{coefficient: coefficient}) do
    abs(coefficient) >= 0.7
  end

  @spec strength_label(t()) :: String.t()
  def strength_label(%__MODULE__{coefficient: coefficient}) do
    abs_coeff = abs(coefficient)

    cond do
      abs_coeff >= 0.7 -> "Strong"
      abs_coeff >= 0.4 -> "Moderate"
      abs_coeff >= 0.2 -> "Weak"
      true -> "Negligible"
    end
  end
end
