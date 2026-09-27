defmodule MetricFlow.Repo.Migrations.AddTypeAndStatusToProcessedStripeEvents do
  use Ecto.Migration

  def change do
    alter table(:processed_stripe_events) do
      add :event_type, :string
      add :status, :string, default: "processing", null: false
    end
  end
end
