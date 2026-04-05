defmodule MetricFlow.Ai.Insight do
  @moduledoc """
  Ecto schema storing an AI-generated insight derived from correlation analysis.

  Each record represents one actionable recommendation produced by the
  InsightsGenerator for a given account, optionally linked to the specific
  CorrelationResult that motivated it.

  Insights carry a suggestion_type enum that categorises the recommended action,
  a confidence float scored between 0.0 and 1.0, and a metadata map for
  supplementary context such as metric names and correlation values.

  Belongs to Account and optionally belongs to CorrelationResult.
  Has many SuggestionFeedback records that capture user ratings.

  suggestion_type categories:
  - :budget_increase  — recommend a direct spend increase
  - :budget_decrease  — recommend a direct spend decrease
  - :optimization     — recommend a configuration or targeting change with no spend change
  - :monitoring       — recommend continued observation with no immediate action
  - :general          — informational, does not correspond to a specific action

  High-confidence threshold: confidence >= 0.7
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Correlations.CorrelationResult

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: integer() | nil,
          correlation_result_id: integer() | nil,
          content: String.t() | nil,
          summary: String.t() | nil,
          suggestion_type: atom() | nil,
          confidence: float() | nil,
          metadata: map(),
          generated_at: DateTime.t() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          correlation_result: CorrelationResult.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @suggestion_types [:budget_increase, :budget_decrease, :optimization, :monitoring, :general]

  @high_confidence_threshold 0.7

  schema "insights" do
    field :content, :string
    field :summary, :string
    field :suggestion_type, Ecto.Enum, values: @suggestion_types
    field :confidence, :float
    field :metadata, :map, default: %{}
    field :generated_at, :utc_datetime_usec

    belongs_to :account, Account
    belongs_to :correlation_result, CorrelationResult

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [
      :account_id,
      :correlation_result_id,
      :content,
      :summary,
      :suggestion_type,
      :confidence,
      :metadata,
      :generated_at
    ])
    |> validate_required([
      :account_id,
      :content,
      :summary,
      :suggestion_type,
      :confidence,
      :generated_at
    ])
    |> validate_length(:content, min: 1)
    |> validate_length(:summary, max: 2000)
    |> validate_number(:confidence,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> assoc_constraint(:account)
    |> maybe_constrain_correlation_result()
  end

  @spec actionable?(t()) :: boolean()
  def actionable?(%__MODULE__{suggestion_type: :monitoring}), do: false
  def actionable?(%__MODULE__{suggestion_type: :general}), do: false
  def actionable?(%__MODULE__{}), do: true

  @spec high_confidence?(t()) :: boolean()
  def high_confidence?(%__MODULE__{confidence: confidence}) do
    confidence >= @high_confidence_threshold
  end

  defp maybe_constrain_correlation_result(%Ecto.Changeset{changes: %{correlation_result_id: id}} = changeset)
       when not is_nil(id) do
    assoc_constraint(changeset, :correlation_result)
  end

  defp maybe_constrain_correlation_result(changeset), do: changeset
end
