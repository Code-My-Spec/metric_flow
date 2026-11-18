defmodule MetricFlow.Repo.Migrations.MergeGoogleIntegrations do
  @moduledoc """
  Folds each account's per-product Google integrations (google_analytics,
  google_ads, google_search_console, google_business, and any existing
  google row) into ONE `google` integration:

    * tokens (access/refresh token, expires_at, reconnection_notified_at) —
      from one "token source" row: one with a refresh token first, then the
      one granting the most Google product scopes, then the latest expires_at
    * granted_scopes — the union of the scopes of every row signed in as the
      same Google user as the token source (a scope another Google login
      granted is not usable with this token)
    * provider_metadata — every row's metadata merged (oldest update first;
      selection keys such as property_id / customer_id / site_url /
      included_locations don't collide), then the token source's on top so
      the identity (email, provider_user_id) matches the token
    * user_id / inserted_at — from the earliest-connected row

  sync_jobs, sync_history and reviews pointing at a merged-away row are
  repointed to the kept row before it is deleted (their foreign keys cascade
  on delete, so history would otherwise be lost). Metrics are tagged with
  the product provider and carry no integration id; they are untouched.

  Rows are grouped by account; legacy rows with no account yet are grouped
  by user.
  """

  use Ecto.Migration

  import Ecto.Query

  @google_family ~w(google_analytics google_ads google_search_console google_business google)

  @product_scopes ~w(
    https://www.googleapis.com/auth/analytics.readonly
    https://www.googleapis.com/auth/adwords
    https://www.googleapis.com/auth/webmasters.readonly
    https://www.googleapis.com/auth/business.manage
  )

  def up, do: merge(repo())

  def down do
    raise Ecto.MigrationError, message: "merge_google_integrations is irreversible"
  end

  @doc "Runs the merge against `repo` (public so tests can drive it)."
  def merge(repo) do
    rows =
      repo.all(
        from(i in "integrations",
          where: i.provider in ^@google_family,
          select: %{
            id: i.id,
            provider: i.provider,
            account_id: i.account_id,
            user_id: i.user_id,
            has_refresh_token: not is_nil(i.refresh_token),
            expires_at: i.expires_at,
            granted_scopes: i.granted_scopes,
            provider_metadata: i.provider_metadata,
            inserted_at: i.inserted_at,
            updated_at: i.updated_at
          }
        )
      )

    rows
    |> Enum.group_by(&group_key/1)
    |> Enum.each(fn {_key, group} -> merge_group(repo, group) end)
  end

  @doc false
  def group_key(%{account_id: nil, user_id: user_id}), do: {:user, user_id}
  def group_key(%{account_id: account_id}), do: {:account, account_id}

  @doc false
  def plan(group) do
    earliest = Enum.min_by(group, & &1.inserted_at, NaiveDateTime)
    kept = Enum.find(group, &(&1.provider == "google")) || earliest

    token_source =
      Enum.max_by(group, fn row ->
        {row.has_refresh_token, Enum.count(row.granted_scopes || [], &(&1 in @product_scopes)),
         NaiveDateTime.to_iso8601(row.expires_at)}
      end)

    metadata =
      group
      |> Enum.sort_by(& &1.updated_at, NaiveDateTime)
      |> Enum.reduce(%{}, &Map.merge(&2, &1.provider_metadata || %{}))
      |> Map.merge(token_source.provider_metadata || %{})

    google_user = google_user(token_source)

    scopes =
      group
      |> Enum.filter(&(is_nil(google_user) or google_user(&1) in [nil, google_user]))
      |> Enum.flat_map(&(&1.granted_scopes || []))
      |> Enum.uniq()

    %{
      kept_id: kept.id,
      token_source_id: token_source.id,
      user_id: earliest.user_id,
      inserted_at: earliest.inserted_at,
      granted_scopes: scopes,
      provider_metadata: metadata,
      merged_ids: group |> Enum.map(& &1.id) |> List.delete(kept.id)
    }
  end

  defp google_user(row), do: (row.provider_metadata || %{})["provider_user_id"]

  defp merge_group(repo, group) do
    plan = plan(group)

    for table <- ~w(sync_jobs sync_history reviews), plan.merged_ids != [] do
      repo.query!(
        "UPDATE #{table} SET integration_id = $1 WHERE integration_id = ANY($2)",
        [plan.kept_id, plan.merged_ids]
      )
    end

    # Copy the token columns from the source row while it still exists.
    repo.query!(
      """
      UPDATE integrations AS k
      SET access_token = s.access_token,
          refresh_token = s.refresh_token,
          expires_at = s.expires_at,
          reconnection_notified_at = s.reconnection_notified_at
      FROM integrations AS s
      WHERE k.id = $1 AND s.id = $2
      """,
      [plan.kept_id, plan.token_source_id]
    )

    if plan.merged_ids != [] do
      repo.query!("DELETE FROM integrations WHERE id = ANY($1)", [plan.merged_ids])
    end

    repo.query!(
      """
      UPDATE integrations
      SET provider = 'google',
          user_id = $2,
          inserted_at = $3,
          granted_scopes = $4,
          provider_metadata = $5,
          updated_at = (now() AT TIME ZONE 'utc')
      WHERE id = $1
      """,
      [
        plan.kept_id,
        plan.user_id,
        plan.inserted_at,
        plan.granted_scopes,
        plan.provider_metadata
      ]
    )
  end
end
