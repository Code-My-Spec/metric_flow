defmodule MetricFlow.Repo.Migrations.AddProviderErrorDetailToSyncHistory do
  use Ecto.Migration

  def change do
    alter table(:sync_history) do
      add :provider_error_detail, :map
    end
  end
end
