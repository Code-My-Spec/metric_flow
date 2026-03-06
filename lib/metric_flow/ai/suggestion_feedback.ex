defmodule MetricFlow.Ai.SuggestionFeedback do
  @moduledoc """
  Ecto schema recording user feedback on AI-generated insights.

  Each record captures whether a user found a suggestion helpful or not, along
  with an optional free-text comment. Enforces a unique constraint on
  [insight_id, user_id] so each user can submit at most one feedback record per
  insight; the context layer upserts on this constraint to allow rating changes.

  Belongs to Insight and User.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Ai.Insight
  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          insight_id: integer() | nil,
          user_id: integer() | nil,
          rating: atom() | nil,
          comment: String.t() | nil,
          insight: Insight.t() | Ecto.Association.NotLoaded.t(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @ratings [:helpful, :not_helpful]

  schema "suggestion_feedback" do
    field :rating, Ecto.Enum, values: @ratings
    field :comment, :string, default: nil

    belongs_to :insight, Insight
    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(suggestion_feedback, attrs) do
    suggestion_feedback
    |> cast(attrs, [:insight_id, :user_id, :rating, :comment])
    |> validate_required([:insight_id, :user_id, :rating])
    |> validate_length(:comment, max: 1000)
    |> assoc_constraint(:insight)
    |> assoc_constraint(:user)
    |> unique_constraint([:insight_id, :user_id],
      name: :suggestion_feedback_insight_id_user_id_index
    )
  end

  @spec helpful?(t()) :: boolean()
  def helpful?(%__MODULE__{rating: :helpful}), do: true
  def helpful?(%__MODULE__{}), do: false
end
