defmodule MetricFlow.Repo.Migrations.MakeSyncHistoryRefsOptional do
  use Ecto.Migration

  def change do
    alter table(:sync_history) do
      modify :integration_id, references(:integrations, on_delete: :delete_all),
        null: true,
        from: references(:integrations, on_delete: :delete_all)

      modify :sync_job_id, references(:sync_jobs, on_delete: :delete_all),
        null: true,
        from: references(:sync_jobs, on_delete: :delete_all)
    end
  end
end
