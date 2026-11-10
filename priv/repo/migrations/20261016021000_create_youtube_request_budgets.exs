defmodule MetricFlow.Repo.Migrations.CreateYoutubeRequestBudgets do
  use Ecto.Migration

  def change do
    create table(:youtube_request_budgets, primary_key: false) do
      add :api, :string, primary_key: true
      add :window_started_at, :utc_datetime_usec, null: false
      add :requests, :integer, null: false, default: 0
      add :blocked, :boolean, null: false, default: false
    end

    create constraint(:youtube_request_budgets, :youtube_request_budgets_nonnegative,
             check: "requests >= 0"
           )
  end
end
