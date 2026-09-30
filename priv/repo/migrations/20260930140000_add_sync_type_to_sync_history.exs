defmodule MetricFlow.Repo.Migrations.AddSyncTypeToSyncHistory do
  use Ecto.Migration

  def change do
    alter table(:sync_history) do
      add :sync_type, :string
    end
  end
end
