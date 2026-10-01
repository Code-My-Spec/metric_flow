defmodule MetricFlow.Repo.Migrations.CreateCorrelationGoalQueue do
  use Ecto.Migration

  def change do
    create table(:correlation_goal_queue) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :goal_metric_name, :string, null: false
      add :time_window, :string, null: false, default: "days_90"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:correlation_goal_queue, [:account_id, :inserted_at])
  end
end
