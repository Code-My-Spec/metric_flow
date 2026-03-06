defmodule MetricFlow.Repo.Migrations.CreateInsights do
  use Ecto.Migration

  def change do
    create table(:insights) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :correlation_result_id, references(:correlation_results, on_delete: :nilify_all)
      add :content, :text, null: false
      add :summary, :string, null: false
      add :suggestion_type, :string, null: false
      add :confidence, :float, null: false
      add :metadata, :map, null: false, default: %{}
      add :generated_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:insights, [:account_id])
    create index(:insights, [:correlation_result_id])
    create index(:insights, [:suggestion_type])
    create index(:insights, [:account_id, :suggestion_type])
  end
end
