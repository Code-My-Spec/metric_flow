defmodule MetricFlow.Repo.Migrations.CreateSyncJobs do
  use Ecto.Migration

  def change do
    create table(:sync_jobs) do
      add :provider, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :error_message, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :integration_id, references(:integrations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:sync_jobs, [:user_id])
    create index(:sync_jobs, [:integration_id])
    create index(:sync_jobs, [:user_id, :status])
  end
end
