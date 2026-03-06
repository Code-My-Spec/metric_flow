defmodule MetricFlow.Repo.Migrations.CreateCorrelationJobs do
  use Ecto.Migration

  def change do
    create table(:correlation_jobs) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :goal_metric_name, :string, null: false
      add :data_window_start, :date
      add :data_window_end, :date
      add :data_points, :integer
      add :results_count, :integer
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :error_message, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:correlation_jobs, [:account_id])
    create index(:correlation_jobs, [:account_id, :status])
  end
end
