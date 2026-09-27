defmodule MetricFlow.Repo.Migrations.AddProcessedStripeEvents do
  use Ecto.Migration

  def change do
    create table(:processed_stripe_events) do
      add :stripe_event_id, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:processed_stripe_events, [:stripe_event_id])
  end
end
