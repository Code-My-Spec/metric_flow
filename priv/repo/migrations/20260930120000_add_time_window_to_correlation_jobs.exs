defmodule MetricFlow.Repo.Migrations.AddTimeWindowToCorrelationJobs do
  use Ecto.Migration

  def change do
    alter table(:correlation_jobs) do
      add :time_window, :string, null: false, default: "days_90"
    end
  end
end
