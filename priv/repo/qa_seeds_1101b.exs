Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
MetricFlow.Repo.start_link([])

alias MetricFlow.Billing.Plan
alias MetricFlow.Repo

plan =
  case Repo.get_by(Plan, name: "QA Rotation Plan", agency_account_id: 31) do
    nil ->
      %Plan{}
      |> Plan.changeset(%{
        name: "QA Rotation Plan",
        price_cents: 4900,
        currency: "usd",
        billing_interval: :monthly,
        agency_account_id: 31,
        stripe_price_id: "price_qa1101_original"
      })
      |> Repo.insert!()

    existing ->
      existing
  end

IO.puts("plan id=#{plan.id} stripe_price_id=#{plan.stripe_price_id} price_cents=#{plan.price_cents}")
