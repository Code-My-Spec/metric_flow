defmodule MetricFlow.Repo.Migrations.AddPlatformFilterToDashboards do
  use Ecto.Migration

  def change do
    alter table(:dashboards) do
      add :platform_filter, :string
    end
  end
end
