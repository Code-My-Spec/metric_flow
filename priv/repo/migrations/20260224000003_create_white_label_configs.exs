defmodule MetricFlow.Repo.Migrations.CreateWhiteLabelConfigs do
  use Ecto.Migration

  def change do
    create table(:white_label_configs) do
      add :agency_id, references(:accounts, on_delete: :delete_all), null: false
      add :logo_url, :string, size: 500
      add :primary_color, :string, size: 7
      add :secondary_color, :string, size: 7
      add :subdomain, :string, null: false
      add :custom_css, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:white_label_configs, [:subdomain])
    create index(:white_label_configs, [:agency_id])
  end
end
