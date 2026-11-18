defmodule MetricFlow.Repo.Migrations.MoveDataOwnershipToAccountsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AgenciesFixtures, only: [account_fixture: 1]

  alias MetricFlow.Repo

  @migration MetricFlow.Repo.Migrations.MoveDataOwnershipToAccounts

  unless Code.ensure_loaded?(@migration) do
    Code.require_file(
      Path.expand(
        "../../../priv/repo/migrations/20261117000000_move_data_ownership_to_accounts.exs",
        __DIR__
      )
    )
  end

  defp legacy_metric!(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {1, [%{id: id}]} =
      Repo.insert_all(
        "metrics",
        [
          %{
            user_id: user_id,
            account_id: nil,
            metric_type: "traffic",
            metric_name: "sessions",
            value: 1.0,
            recorded_at: now,
            provider: "google_analytics",
            dimensions: %{},
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    id
  end

  defp account_id_of(metric_id) do
    Repo.one!(from(m in "metrics", where: m.id == ^metric_id, select: m.account_id))
  end

  test "backfills users with exactly one originated account and leaves ambiguous users NULL" do
    single = user_fixture()
    own = account_fixture(%{type: "client", originator_user_id: single.id})

    several = user_fixture()
    account_fixture(%{type: "client", originator_user_id: several.id})
    account_fixture(%{type: "agency", originator_user_id: several.id})

    none = user_fixture()

    single_metric = legacy_metric!(single.id)
    several_metric = legacy_metric!(several.id)
    none_metric = legacy_metric!(none.id)

    Repo.query!(@migration.backfill_by_user_sql(:metrics))

    assert account_id_of(single_metric) == own.id
    assert account_id_of(several_metric) == nil
    assert account_id_of(none_metric) == nil
  end
end
