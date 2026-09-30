defmodule MetricFlow.Repo.Migrations.AddFavoriteAndDateRangeToVisualizations do
  use Ecto.Migration

  def change do
    alter table(:visualizations) do
      add :is_favorite, :boolean, default: false, null: false
      add :last_viewed_date_range, :string
    end
  end
end
