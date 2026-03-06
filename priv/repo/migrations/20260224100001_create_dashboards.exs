defmodule MetricFlow.Repo.Migrations.CreateDashboards do
  use Ecto.Migration

  def change do
    create table(:dashboards) do
      add :name, :string, null: false
      add :description, :string
      add :built_in, :boolean, null: false, default: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:dashboards, [:user_id])
  end
end
