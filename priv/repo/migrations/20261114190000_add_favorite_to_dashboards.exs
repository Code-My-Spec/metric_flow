defmodule MetricFlow.Repo.Migrations.AddFavoriteToDashboards do
  use Ecto.Migration

  def change do
    alter table(:dashboards) do
      add :favorite, :boolean, default: false, null: false
    end
  end
end
