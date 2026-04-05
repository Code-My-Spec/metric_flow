defmodule MetricFlow.Repo.Migrations.AlterInsightsTextColumns do
  use Ecto.Migration

  def change do
    alter table(:insights) do
      modify :summary, :text, from: :string
      modify :content, :text, from: :string
    end
  end
end
