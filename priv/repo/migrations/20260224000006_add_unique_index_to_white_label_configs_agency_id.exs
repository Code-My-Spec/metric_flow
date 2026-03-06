defmodule MetricFlow.Repo.Migrations.AddUniqueIndexToWhiteLabelConfigsAgencyId do
  use Ecto.Migration

  def change do
    drop_if_exists index(:white_label_configs, [:agency_id])
    create unique_index(:white_label_configs, [:agency_id])
  end
end
