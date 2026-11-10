# Grants the existing synthetic QA account local access to paywalled screens.
# Usage: DATABASE_NAME=metric_flow_dev_wc_<copy-id> mix run priv/repo/qa_seeds_visualization_access.exs
# Never run against a shared, production, or non-clone database.

alias MetricFlow.Accounts
alias MetricFlow.Accounts.AccountMember
alias MetricFlow.Billing.BillingRepository
alias MetricFlow.Billing.Subscription
alias MetricFlow.Repo
alias MetricFlow.Users
alias MetricFlow.Users.Scope

database_name = System.fetch_env!("DATABASE_NAME")

unless Mix.env() == :dev and
         Regex.match?(~r/^metric_flow_dev_wc_[a-z0-9]+$/, database_name) and
         Repo.config()[:database] == database_name do
  raise "QA entitlement seed requires a development working-copy clone database"
end

user = Users.get_user_by_email("qa@example.com") || raise("QA user is missing")

account =
  user
  |> Scope.for_user()
  |> Accounts.list_accounts()
  |> Enum.find(&(&1.name == "QA Test Account" and &1.type == :client)) ||
    raise("QA Test Account is missing")

unless Repo.get_by(AccountMember, account_id: account.id, user_id: user.id, role: :owner) do
  raise "QA user does not own QA Test Account"
end

stripe_id = "sub_test_visualization_qa_#{account.id}"
customer_id = "cus_test_visualization_qa_#{account.id}"

case Repo.get_by(Subscription, account_id: account.id) do
  nil -> :ok
  %{stripe_subscription_id: ^stripe_id} -> :ok
  _ -> raise "QA Test Account has a different subscription; refusing to alter it"
end

now = DateTime.utc_now() |> DateTime.truncate(:second)

{:ok, subscription} =
  BillingRepository.upsert_subscription(%{
    stripe_subscription_id: stripe_id,
    stripe_customer_id: customer_id,
    account_id: account.id,
    status: :active,
    current_period_start: now,
    current_period_end: DateTime.add(now, 30, :day)
  })

IO.puts(
  "QA visualization entitlement ready: database=#{database_name} account_id=#{account.id} subscription_id=#{subscription.id}"
)
