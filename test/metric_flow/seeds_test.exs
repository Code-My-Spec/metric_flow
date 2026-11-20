defmodule MetricFlow.SeedsTest do
  @moduledoc """
  Guards the sample-data seed script required by the design pass:
  it must be non-empty, must refuse to run outside :dev/:test, must
  create the headline users and accounts, and must be idempotent.
  """

  use MetricFlowTest.DataCase, async: false

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Ai.ChatSession
  alias MetricFlow.Correlations.CorrelationResult
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo
  alias MetricFlow.Users
  alias MetricFlow.Users.User

  @seeds_path Path.expand("../../priv/repo/seeds.exs", __DIR__)

  test "seeds.exs is substantive and guards non-dev/test environments" do
    contents = File.read!(@seeds_path)

    refute String.trim(contents) == "",
           "priv/repo/seeds.exs is empty — nothing is being seeded"

    assert String.length(contents) > 400,
           "priv/repo/seeds.exs is too small (#{String.length(contents)} bytes) to be seeding anything believable"

    assert contents =~ ~r/Mix\.env|config_env/,
           "seeds.exs must guard against UAT/prod (no environment check found)"

    assert contents =~ ~r/:dev/ and contents =~ ~r/:test/,
           "seeds.exs must allow only :dev and :test"
  end

  test "running seeds.exs populates the headline sample data" do
    Code.eval_file(@seeds_path)

    assert %User{} = Users.get_user_by_email("joel@example.com"),
           "expected joel@example.com to be seeded"

    assert Users.get_user_by_email("client@example.com"),
           "expected a client user to be seeded"

    assert Users.get_user_by_email("direct@example.com"),
           "expected a direct-marketer user to be seeded"

    agency = Repo.get_by(Account, name: "Anderson the Fish")
    assert agency, "agency account \"Anderson the Fish\" was not seeded"
    assert agency.type == :agency

    retail = Repo.get_by(Account, name: "Anderson Retail Co.")
    assert retail, "client account \"Anderson Retail Co.\" was not seeded"
    assert retail.type == :client

    assert Repo.exists?(from(i in Integration, where: i.account_id == ^retail.id)),
           "expected integrations to be seeded on the client account"

    assert Repo.aggregate(from(m in Metric, where: m.account_id == ^retail.id), :count) >= 90,
           "expected ~90 days of metrics on the client account"

    assert Repo.exists?(from(r in CorrelationResult, where: r.account_id == ^retail.id)),
           "expected correlation results on the client account"

    chat_count =
      Repo.aggregate(from(s in ChatSession, where: s.account_id == ^retail.id), :count)

    assert chat_count >= 5, "expected at least 5 chat sessions, got #{chat_count}"
  end

  test "running seeds.exs twice is idempotent" do
    Code.eval_file(@seeds_path)
    user_count = Repo.aggregate(User, :count)
    account_count = Repo.aggregate(Account, :count)
    metric_count = Repo.aggregate(Metric, :count)
    chat_count = Repo.aggregate(ChatSession, :count)

    Code.eval_file(@seeds_path)

    assert Repo.aggregate(User, :count) == user_count
    assert Repo.aggregate(Account, :count) == account_count
    assert Repo.aggregate(Metric, :count) == metric_count
    assert Repo.aggregate(ChatSession, :count) == chat_count
  end
end
