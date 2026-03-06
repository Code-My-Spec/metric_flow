defmodule MetricFlow.Repo.Migrations.CreateCorrelationResults do
  use Ecto.Migration

  def change do
    create table(:correlation_results) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :correlation_job_id, references(:correlation_jobs, on_delete: :delete_all), null: false
      add :metric_name, :string, null: false
      add :goal_metric_name, :string, null: false
      add :coefficient, :float, null: false
      add :optimal_lag, :integer, null: false
      add :data_points, :integer, null: false
      add :provider, :string
      add :calculated_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:correlation_results, [:account_id])
    create index(:correlation_results, [:correlation_job_id])

    create unique_index(:correlation_results, [
      :account_id,
      :correlation_job_id,
      :metric_name,
      :goal_metric_name
    ])
  end
end
