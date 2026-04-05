defmodule MetricFlow.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:reviews) do
      add :integration_id, references(:integrations, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :external_review_id, :string, null: false
      add :reviewer_name, :string
      add :star_rating, :integer
      add :comment, :text
      add :review_date, :date, null: false
      add :location_id, :string
      add :metadata, :map, null: false, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:reviews, [:user_id, :provider])
    create index(:reviews, [:user_id, :review_date])
    create unique_index(:reviews, [:external_review_id])
  end
end
