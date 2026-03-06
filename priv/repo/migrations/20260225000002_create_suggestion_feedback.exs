defmodule MetricFlow.Repo.Migrations.CreateSuggestionFeedback do
  use Ecto.Migration

  def change do
    create table(:suggestion_feedback) do
      add :insight_id, references(:insights, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :rating, :string, null: false
      add :comment, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:suggestion_feedback, [:insight_id])
    create index(:suggestion_feedback, [:user_id])

    create unique_index(:suggestion_feedback, [:insight_id, :user_id])
  end
end
