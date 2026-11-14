defmodule MetricFlow.Repo.Migrations.AddDateRangeToDashboards do
  use Ecto.Migration

  def change do
    alter table(:dashboards) do
      add :date_range, :string, default: "30", null: false
    end
  end
end
