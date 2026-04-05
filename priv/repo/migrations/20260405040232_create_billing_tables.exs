defmodule MetricFlow.Repo.Migrations.CreateBillingTables do
  use Ecto.Migration

  def change do
    create table(:billing_plans) do
      add :name, :string, null: false
      add :description, :text
      add :price_cents, :integer, null: false
      add :currency, :string, null: false, default: "usd"
      add :billing_interval, :string, null: false, default: "monthly"
      add :stripe_price_id, :string
      add :active, :boolean, null: false, default: true
      add :agency_account_id, references(:accounts, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:billing_plans, [:agency_account_id])
    create unique_index(:billing_plans, [:stripe_price_id], where: "stripe_price_id IS NOT NULL")

    create table(:billing_subscriptions) do
      add :stripe_subscription_id, :string, null: false
      add :stripe_customer_id, :string, null: false
      add :status, :string, null: false, default: "active"
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :plan_id, references(:billing_plans, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:billing_subscriptions, [:stripe_subscription_id])
    create unique_index(:billing_subscriptions, [:account_id])
    create index(:billing_subscriptions, [:plan_id])

    create table(:billing_stripe_accounts) do
      add :stripe_account_id, :string, null: false
      add :onboarding_status, :string, null: false, default: "pending"
      add :capabilities, :map, null: false, default: %{}
      add :agency_account_id, references(:accounts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:billing_stripe_accounts, [:agency_account_id])
    create unique_index(:billing_stripe_accounts, [:stripe_account_id])
  end
end
