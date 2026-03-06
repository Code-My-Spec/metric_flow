defmodule MetricFlow.Repo.Migrations.CreateVisualizations do
  use Ecto.Migration

  def change do
    create table(:visualizations) do
      add :name, :string, null: false
      add :vega_spec, :map, null: false
      add :shareable, :boolean, null: false, default: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:visualizations, [:user_id])
    create index(:visualizations, [:user_id, :shareable])
  end
end
