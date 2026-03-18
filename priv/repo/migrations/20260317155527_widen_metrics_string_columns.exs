defmodule MetricFlow.Repo.Migrations.WidenMetricsStringColumns do
  use Ecto.Migration

  def change do
    alter table(:metrics) do
      modify :metric_type, :text, from: :string
      modify :metric_name, :text, from: :string
    end

    alter table(:sync_history) do
      modify :error_message, :text, from: :string
    end

    alter table(:sync_jobs) do
      modify :error_message, :text, from: :string
    end
  end
end
