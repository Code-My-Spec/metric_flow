defmodule MetricFlow.Repo.Migrations.AddCorrelationViewModeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :correlation_view_mode, :string, default: "raw", null: false
    end
  end
end
