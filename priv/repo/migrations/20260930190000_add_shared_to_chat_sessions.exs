defmodule MetricFlow.Repo.Migrations.AddSharedToChatSessions do
  use Ecto.Migration

  def change do
    alter table(:chat_sessions) do
      add :shared, :boolean, default: false, null: false
    end
  end
end
