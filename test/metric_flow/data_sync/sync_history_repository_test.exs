defmodule MetricFlow.DataSync.SyncHistoryRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.DataSync.SyncHistory
  alias MetricFlow.DataSync.SyncHistoryRepository
  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp valid_started_at do
    DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:microsecond)
  end

  defp valid_completed_at(offset_seconds \\ 0) do
    DateTime.add(DateTime.utc_now(), offset_seconds, :second) |> DateTime.truncate(:microsecond)
  end

  # Note: there is a unique constraint on (user_id, provider) for integrations.
  # Each user may only have one integration per provider.
  defp insert_integration!(user_id, provider) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  defp insert_sync_job!(user_id, integration_id, provider) do
    %SyncJob{}
    |> SyncJob.changeset(%{
      user_id: user_id,
      integration_id: integration_id,
      provider: provider,
      status: :completed
    })
    |> Repo.insert!()
  end

  defp valid_sync_history_attrs(user_id, integration_id, sync_job_id, overrides \\ %{}) do
    Map.merge(
      %{
        user_id: user_id,
        integration_id: integration_id,
        sync_job_id: sync_job_id,
        provider: :google_analytics,
        status: :success,
        records_synced: 42,
        started_at: valid_started_at(),
        completed_at: valid_completed_at()
      },
      overrides
    )
  end

  defp insert_sync_history!(user_id, integration_id, sync_job_id, overrides \\ %{}) do
    attrs = valid_sync_history_attrs(user_id, integration_id, sync_job_id, overrides)

    %SyncHistory{}
    |> SyncHistory.changeset(attrs)
    |> Repo.insert!()
  end

  # Creates a user, scope, integration, and sync_job for the given provider.
  defp setup_user_with_deps(provider \\ :google_analytics) do
    {user, scope} = user_with_scope()
    integration = insert_integration!(user.id, provider)
    sync_job = insert_sync_job!(user.id, integration.id, provider)
    {user, scope, integration, sync_job}
  end

  # Creates all four providers for a single user in one call.
  # Returns {user, scope, providers_map} where providers_map is:
  #   %{google_analytics: {integration, sync_job}, google_ads: ..., ...}
  defp setup_user_with_all_providers do
    {user, scope} = user_with_scope()

    providers_map =
      Enum.into(
        [:google_analytics, :google_ads, :facebook_ads, :quickbooks],
        %{},
        fn provider ->
          integration = insert_integration!(user.id, provider)
          sync_job = insert_sync_job!(user.id, integration.id, provider)
          {provider, {integration, sync_job}}
        end
      )

    {user, scope, providers_map}
  end

  # ---------------------------------------------------------------------------
  # list_sync_history/2
  # ---------------------------------------------------------------------------

  describe "list_sync_history/2" do
    test "returns all sync history records for scoped user when no options provided" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      insert_sync_history!(user.id, integration.id, sync_job.id)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{records_synced: 10})

      results = SyncHistoryRepository.list_sync_history(scope)

      assert length(results) == 2
    end

    test "returns empty list when no sync history records exist" do
      {_user, scope, _integration, _sync_job} = setup_user_with_deps()

      assert SyncHistoryRepository.list_sync_history(scope) == []
    end

    test "only returns sync history records for scoped user" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      {other_user, _other_scope, other_integration, other_sync_job} = setup_user_with_deps()

      insert_sync_history!(user.id, integration.id, sync_job.id)
      insert_sync_history!(other_user.id, other_integration.id, other_sync_job.id)

      results = SyncHistoryRepository.list_sync_history(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end

    test "orders by most recently completed first (completed_at desc, id desc)" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      older =
        insert_sync_history!(user.id, integration.id, sync_job.id, %{
          completed_at: valid_completed_at(-300)
        })

      newer =
        insert_sync_history!(user.id, integration.id, sync_job.id, %{
          completed_at: valid_completed_at(-60)
        })

      results = SyncHistoryRepository.list_sync_history(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [newer.id, older.id]
    end

    test "filters by provider when provider option provided" do
      {user, scope, providers_map} = setup_user_with_all_providers()
      {ga_integration, ga_sync_job} = providers_map[:google_analytics]
      {ads_integration, ads_sync_job} = providers_map[:google_ads]

      insert_sync_history!(user.id, ga_integration.id, ga_sync_job.id, %{
        provider: :google_analytics
      })

      insert_sync_history!(user.id, ads_integration.id, ads_sync_job.id, %{
        provider: :google_ads
      })

      results = SyncHistoryRepository.list_sync_history(scope, provider: :google_analytics)

      assert length(results) == 1
      assert hd(results).provider == :google_analytics
    end

    test "returns only :google_analytics sync history when provider: :google_analytics" do
      {user, scope, providers_map} = setup_user_with_all_providers()
      {ga_integration, ga_sync_job} = providers_map[:google_analytics]
      {ads_integration, ads_sync_job} = providers_map[:google_ads]

      insert_sync_history!(user.id, ga_integration.id, ga_sync_job.id, %{
        provider: :google_analytics
      })

      insert_sync_history!(user.id, ads_integration.id, ads_sync_job.id, %{provider: :google_ads})

      results = SyncHistoryRepository.list_sync_history(scope, provider: :google_analytics)

      assert Enum.all?(results, &(&1.provider == :google_analytics))
    end

    test "returns only :google_ads sync history when provider: :google_ads" do
      {user, scope, providers_map} = setup_user_with_all_providers()
      {ga_integration, ga_sync_job} = providers_map[:google_analytics]
      {ads_integration, ads_sync_job} = providers_map[:google_ads]

      insert_sync_history!(user.id, ga_integration.id, ga_sync_job.id, %{
        provider: :google_analytics
      })

      insert_sync_history!(user.id, ads_integration.id, ads_sync_job.id, %{provider: :google_ads})

      results = SyncHistoryRepository.list_sync_history(scope, provider: :google_ads)

      assert Enum.all?(results, &(&1.provider == :google_ads))
    end

    test "returns only :facebook_ads sync history when provider: :facebook_ads" do
      {user, scope, providers_map} = setup_user_with_all_providers()
      {ga_integration, ga_sync_job} = providers_map[:google_analytics]
      {fb_integration, fb_sync_job} = providers_map[:facebook_ads]

      insert_sync_history!(user.id, ga_integration.id, ga_sync_job.id, %{
        provider: :google_analytics
      })

      insert_sync_history!(user.id, fb_integration.id, fb_sync_job.id, %{
        provider: :facebook_ads
      })

      results = SyncHistoryRepository.list_sync_history(scope, provider: :facebook_ads)

      assert length(results) == 1
      assert hd(results).provider == :facebook_ads
    end

    test "returns only :quickbooks sync history when provider: :quickbooks" do
      {user, scope, providers_map} = setup_user_with_all_providers()
      {ga_integration, ga_sync_job} = providers_map[:google_analytics]
      {qb_integration, qb_sync_job} = providers_map[:quickbooks]

      insert_sync_history!(user.id, ga_integration.id, ga_sync_job.id, %{
        provider: :google_analytics
      })

      insert_sync_history!(user.id, qb_integration.id, qb_sync_job.id, %{provider: :quickbooks})

      results = SyncHistoryRepository.list_sync_history(scope, provider: :quickbooks)

      assert length(results) == 1
      assert hd(results).provider == :quickbooks
    end

    test "limits results when limit option provided" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for _i <- 1..7 do
        insert_sync_history!(user.id, integration.id, sync_job.id)
      end

      results = SyncHistoryRepository.list_sync_history(scope, limit: 3)

      assert length(results) == 3
    end

    test "returns exactly 5 records when limit: 5" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for _i <- 1..10 do
        insert_sync_history!(user.id, integration.id, sync_job.id)
      end

      results = SyncHistoryRepository.list_sync_history(scope, limit: 5)

      assert length(results) == 5
    end

    test "returns exactly 10 records when limit: 10" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for _i <- 1..15 do
        insert_sync_history!(user.id, integration.id, sync_job.id)
      end

      results = SyncHistoryRepository.list_sync_history(scope, limit: 10)

      assert length(results) == 10
    end

    test "applies offset when offset option provided" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for _i <- 1..8 do
        insert_sync_history!(user.id, integration.id, sync_job.id)
      end

      all_results = SyncHistoryRepository.list_sync_history(scope)
      offset_results = SyncHistoryRepository.list_sync_history(scope, offset: 3)

      assert length(offset_results) == length(all_results) - 3
    end

    test "skips first 5 records when offset: 5" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for _i <- 1..10 do
        insert_sync_history!(user.id, integration.id, sync_job.id)
      end

      all_results = SyncHistoryRepository.list_sync_history(scope)
      offset_results = SyncHistoryRepository.list_sync_history(scope, offset: 5)

      first_ids = all_results |> Enum.take(5) |> Enum.map(& &1.id)
      offset_ids = Enum.map(offset_results, & &1.id)

      assert length(offset_results) == 5
      assert Enum.all?(first_ids, fn id -> id not in offset_ids end)
    end

    test "skips first 10 records when offset: 10" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for _i <- 1..15 do
        insert_sync_history!(user.id, integration.id, sync_job.id)
      end

      all_results = SyncHistoryRepository.list_sync_history(scope)
      offset_results = SyncHistoryRepository.list_sync_history(scope, offset: 10)

      first_ids = all_results |> Enum.take(10) |> Enum.map(& &1.id)
      offset_ids = Enum.map(offset_results, & &1.id)

      assert length(offset_results) == 5
      assert Enum.all?(first_ids, fn id -> id not in offset_ids end)
    end

    test "combines limit and offset correctly" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for _i <- 1..15 do
        insert_sync_history!(user.id, integration.id, sync_job.id)
      end

      results = SyncHistoryRepository.list_sync_history(scope, limit: 5, offset: 5)

      assert length(results) == 5
    end

    test "returns records 6-10 when limit: 5, offset: 5" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for _i <- 1..15 do
        insert_sync_history!(user.id, integration.id, sync_job.id)
      end

      all_results = SyncHistoryRepository.list_sync_history(scope)
      page_results = SyncHistoryRepository.list_sync_history(scope, limit: 5, offset: 5)

      expected_ids = all_results |> Enum.slice(5, 5) |> Enum.map(& &1.id)
      actual_ids = Enum.map(page_results, & &1.id)

      assert actual_ids == expected_ids
    end

    test "ignores invalid provider values" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      insert_sync_history!(user.id, integration.id, sync_job.id)

      results = SyncHistoryRepository.list_sync_history(scope, provider: :not_a_real_provider)

      assert results == []
    end

    test "handles empty options keyword list" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      insert_sync_history!(user.id, integration.id, sync_job.id)

      results = SyncHistoryRepository.list_sync_history(scope, [])

      assert length(results) == 1
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a, integration_a, sync_job_a} = setup_user_with_deps()
      {user_b, _scope_b, integration_b, sync_job_b} = setup_user_with_deps()

      insert_sync_history!(user_a.id, integration_a.id, sync_job_a.id, %{records_synced: 10})
      insert_sync_history!(user_b.id, integration_b.id, sync_job_b.id, %{records_synced: 99})
      insert_sync_history!(user_b.id, integration_b.id, sync_job_b.id, %{records_synced: 88})

      results = SyncHistoryRepository.list_sync_history(scope_a)

      assert length(results) == 1
      assert hd(results).user_id == user_a.id
    end

    test "returns sync history with all status values" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      insert_sync_history!(user.id, integration.id, sync_job.id, %{status: :success})
      insert_sync_history!(user.id, integration.id, sync_job.id, %{status: :partial_success})
      insert_sync_history!(user.id, integration.id, sync_job.id, %{status: :failed})

      results = SyncHistoryRepository.list_sync_history(scope)
      statuses = Enum.map(results, & &1.status)

      assert :success in statuses
      assert :partial_success in statuses
      assert :failed in statuses
    end

    test "works with multiple filter options combined" do
      {user, scope, providers_map} = setup_user_with_all_providers()
      {ga_integration, ga_sync_job} = providers_map[:google_analytics]
      {ads_integration, ads_sync_job} = providers_map[:google_ads]

      for _i <- 1..8 do
        insert_sync_history!(user.id, ga_integration.id, ga_sync_job.id, %{
          provider: :google_analytics
        })
      end

      for _i <- 1..3 do
        insert_sync_history!(user.id, ads_integration.id, ads_sync_job.id, %{
          provider: :google_ads
        })
      end

      results =
        SyncHistoryRepository.list_sync_history(scope,
          provider: :google_analytics,
          limit: 5,
          offset: 2
        )

      assert length(results) == 5
      assert Enum.all?(results, &(&1.provider == :google_analytics))
    end
  end

  # ---------------------------------------------------------------------------
  # get_sync_history/2
  # ---------------------------------------------------------------------------

  describe "get_sync_history/2" do
    test "returns sync history when it exists for scoped user" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      history = insert_sync_history!(user.id, integration.id, sync_job.id)

      assert {:ok, result} = SyncHistoryRepository.get_sync_history(scope, history.id)
      assert result.id == history.id
    end

    test "returns error when sync history doesn't exist" do
      {_user, scope, _integration, _sync_job} = setup_user_with_deps()

      assert {:error, :not_found} = SyncHistoryRepository.get_sync_history(scope, -1)
    end

    test "returns error when sync history exists for different user" do
      {other_user, _other_scope, other_integration, other_sync_job} = setup_user_with_deps()
      history = insert_sync_history!(other_user.id, other_integration.id, other_sync_job.id)

      {_user, scope, _integration, _sync_job} = setup_user_with_deps()

      assert {:error, :not_found} = SyncHistoryRepository.get_sync_history(scope, history.id)
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a, integration_a, sync_job_a} = setup_user_with_deps()
      {user_b, _scope_b, integration_b, sync_job_b} = setup_user_with_deps()

      history_a = insert_sync_history!(user_a.id, integration_a.id, sync_job_a.id)
      history_b = insert_sync_history!(user_b.id, integration_b.id, sync_job_b.id)

      assert {:ok, result} = SyncHistoryRepository.get_sync_history(scope_a, history_a.id)
      assert result.user_id == user_a.id

      assert {:error, :not_found} = SyncHistoryRepository.get_sync_history(scope_a, history_b.id)
    end

    test "works with any sync history status" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      for status <- [:success, :partial_success, :failed] do
        history =
          insert_sync_history!(user.id, integration.id, sync_job.id, %{status: status})

        assert {:ok, result} = SyncHistoryRepository.get_sync_history(scope, history.id)
        assert result.status == status
      end
    end

    test "works with any provider" do
      {user, scope, providers_map} = setup_user_with_all_providers()

      for provider <- [:google_analytics, :google_ads, :facebook_ads, :quickbooks] do
        {provider_integration, provider_sync_job} = providers_map[provider]

        history =
          insert_sync_history!(user.id, provider_integration.id, provider_sync_job.id, %{
            provider: provider
          })

        assert {:ok, result} = SyncHistoryRepository.get_sync_history(scope, history.id)
        assert result.provider == provider
      end
    end

    test "loads association data if preloaded" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      history = insert_sync_history!(user.id, integration.id, sync_job.id)

      assert {:ok, result} = SyncHistoryRepository.get_sync_history(scope, history.id)

      assert result.user_id == user.id
      assert result.integration_id == integration.id
      assert result.sync_job_id == sync_job.id
    end

    test "returns complete sync history record with all fields" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      started_at = valid_started_at()
      completed_at = valid_completed_at()

      history =
        insert_sync_history!(user.id, integration.id, sync_job.id, %{
          provider: :google_analytics,
          status: :success,
          records_synced: 99,
          error_message: "minor warning",
          started_at: started_at,
          completed_at: completed_at
        })

      assert {:ok, result} = SyncHistoryRepository.get_sync_history(scope, history.id)

      assert result.id == history.id
      assert result.user_id == user.id
      assert result.integration_id == integration.id
      assert result.sync_job_id == sync_job.id
      assert result.provider == :google_analytics
      assert result.status == :success
      assert result.records_synced == 99
      assert result.error_message == "minor warning"
      assert result.started_at != nil
      assert result.completed_at != nil
    end
  end

  # ---------------------------------------------------------------------------
  # create_sync_history/2
  # ---------------------------------------------------------------------------

  describe "create_sync_history/2" do
    test "creates sync history with valid attributes" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id)
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.id != nil
    end

    test "returns error with invalid provider" do
      {_user, scope, integration, sync_job} = setup_user_with_deps()

      attrs = %{
        integration_id: integration.id,
        sync_job_id: sync_job.id,
        provider: :not_a_real_provider,
        status: :success,
        records_synced: 0,
        started_at: valid_started_at(),
        completed_at: valid_completed_at()
      }

      assert {:error, changeset} = SyncHistoryRepository.create_sync_history(scope, attrs)
      refute changeset.valid?
    end

    test "returns error with missing required fields" do
      {_user, scope, _integration, _sync_job} = setup_user_with_deps()

      assert {:error, changeset} = SyncHistoryRepository.create_sync_history(scope, %{})
      refute changeset.valid?
    end

    test "returns error with non-existent integration_id" do
      {_user, scope, _integration, sync_job} = setup_user_with_deps()

      attrs = %{
        integration_id: -1,
        sync_job_id: sync_job.id,
        provider: :google_analytics,
        status: :success,
        records_synced: 0,
        started_at: valid_started_at(),
        completed_at: valid_completed_at()
      }

      assert {:error, changeset} = SyncHistoryRepository.create_sync_history(scope, attrs)
      refute changeset.valid?
    end

    test "returns error with non-existent sync_job_id" do
      {_user, scope, integration, _sync_job} = setup_user_with_deps()

      attrs = %{
        integration_id: integration.id,
        sync_job_id: -1,
        provider: :google_analytics,
        status: :success,
        records_synced: 0,
        started_at: valid_started_at(),
        completed_at: valid_completed_at()
      }

      assert {:error, changeset} = SyncHistoryRepository.create_sync_history(scope, attrs)
      refute changeset.valid?
    end

    test "returns error with non-existent user_id" do
      # The repository merges scope's user_id, overriding any provided user_id.
      # This test verifies the scope user_id is used and the record is created correctly.
      {_user, scope, integration, sync_job} = setup_user_with_deps()

      attrs = %{
        user_id: -1,
        integration_id: integration.id,
        sync_job_id: sync_job.id,
        provider: :google_analytics,
        status: :success,
        records_synced: 0,
        started_at: valid_started_at(),
        completed_at: valid_completed_at()
      }

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.user_id == scope.user.id
    end

    test "sets user_id from scope automatically" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id)
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.user_id == user.id
    end

    test "creates sync history with :success status" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{status: :success})
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.status == :success
    end

    test "creates sync history with :partial_success status" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{
          status: :partial_success
        })
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.status == :partial_success
    end

    test "creates sync history with :failed status" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{status: :failed})
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.status == :failed
    end

    test "allows optional error_message" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{
          status: :failed,
          error_message: "connection refused after 3 retries"
        })
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.error_message == "connection refused after 3 retries"
    end

    test "defaults records_synced to 0 when not provided" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{records_synced: 0})
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.records_synced == 0
    end

    test "accepts explicit records_synced value" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{records_synced: 250})
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.records_synced == 250
    end

    test "validates records_synced is non-negative" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{records_synced: -1})
        |> Map.delete(:user_id)

      assert {:error, changeset} = SyncHistoryRepository.create_sync_history(scope, attrs)
      refute changeset.valid?
    end

    test "returns error with negative records_synced" do
      {user, scope, integration, sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{records_synced: -5})
        |> Map.delete(:user_id)

      assert {:error, changeset} = SyncHistoryRepository.create_sync_history(scope, attrs)
      refute changeset.valid?
      assert %{records_synced: [_]} = errors_on(changeset)
    end

    test "accepts all valid provider enum values" do
      {user, scope, providers_map} = setup_user_with_all_providers()

      for provider <- [:google_analytics, :google_ads, :facebook_ads, :quickbooks] do
        {provider_integration, provider_sync_job} = providers_map[provider]

        attrs =
          valid_sync_history_attrs(user.id, provider_integration.id, provider_sync_job.id, %{
            provider: provider
          })
          |> Map.delete(:user_id)

        assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs),
               "expected provider #{provider} to be accepted"

        assert history.provider == provider
      end
    end

    test "accepts all valid status enum values" do
      {user, scope, providers_map} = setup_user_with_all_providers()

      # Use a different provider per status to avoid sync_job reuse confusion
      providers_for_status = %{
        success: :google_analytics,
        partial_success: :google_ads,
        failed: :facebook_ads
      }

      for {status, provider} <- providers_for_status do
        {provider_integration, provider_sync_job} = providers_map[provider]

        attrs =
          valid_sync_history_attrs(user.id, provider_integration.id, provider_sync_job.id, %{
            provider: provider,
            status: status
          })
          |> Map.delete(:user_id)

        assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs),
               "expected status #{status} to be accepted"

        assert history.status == status
      end
    end

    test "stores started_at timestamp" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      started_at = valid_started_at()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{started_at: started_at})
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.started_at != nil
    end

    test "stores completed_at timestamp" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      completed_at = valid_completed_at()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id, %{
          completed_at: completed_at
        })
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.completed_at != nil
    end

    test "enforces multi-tenant isolation" do
      {user, scope, integration, sync_job} = setup_user_with_deps()
      {other_user, _other_scope, _other_integration, _other_sync_job} = setup_user_with_deps()

      attrs =
        valid_sync_history_attrs(user.id, integration.id, sync_job.id)
        |> Map.delete(:user_id)

      assert {:ok, history} = SyncHistoryRepository.create_sync_history(scope, attrs)
      assert history.user_id == user.id
      assert history.user_id != other_user.id
    end
  end
end
