Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
MetricFlow.Repo.start_link([])

import Ecto.Query
alias MetricFlow.Accounts.{Account, AccountMember}
alias MetricFlow.Billing.Plan
alias MetricFlow.Repo
alias MetricFlow.Users

qa_user = Users.get_user_by_email("qa@example.com") || raise "run qa_seeds.exs first"

agency =
  case Repo.get_by(Account, name: "QA Agency 1101") do
    nil ->
      unique = :erlang.unique_integer([:positive])
      account = %Account{} |> Account.creation_changeset(%{name: "QA Agency 1101", slug: "qa-agency-1101-#{unique}", type: "agency", originator_user_id: qa_user.id}) |> Repo.insert!()
      %AccountMember{} |> AccountMember.changeset(%{account_id: account.id, user_id: qa_user.id, role: :owner}) |> Repo.insert!()
      account
    existing -> existing
  end

other_agency_id = 3

cross_plan =
  case Repo.get_by(Plan, name: "Cross-Agency Plan", agency_account_id: other_agency_id) do
    nil -> %Plan{} |> Plan.changeset(%{name: "Cross-Agency Plan", price_cents: 4200, currency: "usd", billing_interval: :monthly, agency_account_id: other_agency_id}) |> Repo.insert!()
    existing -> existing
  end

IO.puts("QA Agency 1101 id=#{agency.id}, cross plan id=#{cross_plan.id} under agency #{other_agency_id}")
