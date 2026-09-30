defmodule MetricFlow.Repo.Migrations.AddAccentColorToWhiteLabelConfigs do
  use Ecto.Migration

  def change do
    alter table(:white_label_configs) do
      add :accent_color, :string
    end
  end
end
