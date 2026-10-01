defmodule MetricFlow.Repo.Migrations.AddReconnectionNotifiedAtToIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :reconnection_notified_at, :utc_datetime_usec
    end
  end
end
