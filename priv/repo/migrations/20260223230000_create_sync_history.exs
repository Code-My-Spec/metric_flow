defmodule MetricFlow.Repo.Migrations.CreateSyncHistory do
  use Ecto.Migration

  def change do
    create table(:sync_history) do
      add :provider, :string, null: false
      add :status, :string, null: false
      add :records_synced, :integer, null: false, default: 0
      add :error_message, :string
      add :started_at, :utc_datetime_usec, null: false
      add :completed_at, :utc_datetime_usec, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :integration_id, references(:integrations, on_delete: :delete_all), null: false
      add :sync_job_id, references(:sync_jobs, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:sync_history, [:user_id])
    create index(:sync_history, [:integration_id])
    create index(:sync_history, [:sync_job_id])
    create index(:sync_history, [:user_id, :status])
  end
end
