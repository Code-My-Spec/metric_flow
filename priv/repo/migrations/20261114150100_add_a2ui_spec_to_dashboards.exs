defmodule MetricFlow.Repo.Migrations.AddA2uiSpecToDashboards do
  use Ecto.Migration

  def change do
    alter table(:dashboards) do
      add :a2ui_spec, :map
    end
  end
end
