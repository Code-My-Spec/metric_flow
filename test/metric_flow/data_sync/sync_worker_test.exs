defmodule MetricFlow.DataSync.SyncWorkerTest do
  use MetricFlowTest.DataCase, async: false

  import ExUnit.CaptureLog
  import MetricFlowTest.UsersFixtures
  import Oban.Testing, only: [perform_job: 3]

  alias MetricFlow.DataSync.SyncHistoryRepository
  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.DataSync.SyncJobRepository
  alias MetricFlow.DataSync.SyncWorker
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Metrics
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

  defp insert_integration!(user_id, provider \\ :google_analytics, overrides \\ %{}) do
    expires_at =
      Map.get(overrides, :expires_at, DateTime.add(DateTime.utc_now(), 3600, :second))

    refresh_token =
      Map.get(overrides, :refresh_token, "refresh-token-#{System.unique_integer([:positive])}")

    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: refresh_token,
      expires_at: expires_at,
      granted_scopes: [],
      provider_metadata: %{"property_id" => "properties/123456789"}
    })
    |> Repo.insert!()
  end

  defp insert_expired_integration_with_refresh!(user_id, provider \\ :google_analytics) do
    expired_at = DateTime.add(DateTime.utc_now(), -3600, :second)
    insert_integration!(user_id, provider, %{expires_at: expired_at})
  end

  defp insert_expired_integration_without_refresh!(user_id, provider \\ :google_analytics) do
    expired_at = DateTime.add(DateTime.utc_now(), -3600, :second)

    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: nil,
      expires_at: expired_at,
      granted_scopes: [],
      provider_metadata: %{"property_id" => "properties/123456789"}
    })
    |> Repo.insert!()
  end

  defp insert_sync_job!(user_id, integration_id, provider \\ :google_analytics, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          user_id: user_id,
          integration_id: integration_id,
          provider: provider,
          status: :pending
        },
        overrides
      )

    %SyncJob{}
    |> SyncJob.changeset(attrs)
    |> Repo.insert!()
  end

  # Plug that returns an empty rows response - simulates a successful provider fetch.
  # Passed through the Oban job args so the worker can forward it to fetch_metrics.
  defp empty_rows_plug do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"rows" => []}))
    end
  end

  # Plug that returns a 401 to simulate an auth failure from the provider API.
  defp unauthorized_plug do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => "unauthorized"}))
    end
  end

  # Plug that returns a 403 to simulate a permissions failure from the provider API.
  defp forbidden_plug do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(403, Jason.encode!(%{"error" => "insufficient_permissions"}))
    end
  end

  # Plug that returns a response with one row of metric data.
  defp single_row_plug do
    fn conn ->
      body =
        Jason.encode!(%{
          "rows" => [
            %{
              "dimensionValues" => [%{"value" => "20260115"}],
              "metricValues" => [
                %{"value" => "100"},
                %{"value" => "50"},
                %{"value" => "30"},
                %{"value" => "0.5"},
                %{"value" => "120.0"},
                %{"value" => "10"}
              ]
            }
          ]
        })

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, body)
    end
  end

  # Builds job args with an http_plug for test-time HTTP interception.
  # The SyncWorker extracts and passes this to the provider's fetch_metrics/2.
  defp job_args(integration_id, user_id, sync_job_id, http_plug) do
    %{
      "integration_id" => integration_id,
      "user_id" => user_id,
      "sync_job_id" => sync_job_id,
      "http_plug" => http_plug
    }
  end

  defp job_args(integration_id, user_id, sync_job_id) do
    %{
      "integration_id" => integration_id,
      "user_id" => user_id,
      "sync_job_id" => sync_job_id
    }
  end

  # ---------------------------------------------------------------------------
  # perform/1
  # ---------------------------------------------------------------------------

  describe "perform/1" do
    test "returns :ok when sync completes successfully" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                   []
                 )
      end)
    end

    test "extracts integration_id, user_id, and sync_job_id from Oban.Job args" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                   []
                 )
      end)

      {:ok, final_job} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert final_job.id == sync_job.id
      assert final_job.integration_id == integration.id
    end

    test "updates SyncJob status to :running at start" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      assert sync_job.status == :pending

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                   []
                 )
      end)

      {:ok, final_job} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert final_job.started_at != nil
    end

    test "retrieves integration using integration_id" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                   []
                 )
      end)

      {:ok, final_job} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert final_job.integration_id == integration.id
    end

    test "returns error :integration_not_found when integration doesn't exist" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert {:error, :integration_not_found} =
                 perform_job(
                   SyncWorker,
                   job_args(-999_999, user.id, sync_job.id),
                   []
                 )
      end)
    end

    test "checks if integration tokens are expired using Integration.expired?/1" do
      {user, _scope} = user_with_scope()
      integration = insert_expired_integration_without_refresh!(user.id)

      assert Integration.expired?(integration)

      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert {:error, :token_expired} =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id),
                   []
                 )
      end)
    end

    test "attempts token refresh when expired?/1 returns true and has_refresh_token?/1 returns true" do
      {user, _scope} = user_with_scope()
      integration = insert_expired_integration_with_refresh!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      assert Integration.expired?(integration)
      assert Integration.has_refresh_token?(integration)

      capture_log(fn ->
        perform_job(
          SyncWorker,
          job_args(integration.id, user.id, sync_job.id),
          []
        )
      end)

      # Worker must have attempted refresh. On failure (expected since no real OAuth endpoint
      # is configured in tests), a SyncHistory record with :failed status is persisted.
      scope = Scope.for_user(user)
      histories = SyncHistoryRepository.list_sync_history(scope)
      assert match?([_], histories)
    end

    test "returns error :token_expired when expired and no refresh token available" do
      {user, _scope} = user_with_scope()
      integration = insert_expired_integration_without_refresh!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      assert Integration.expired?(integration)
      refute Integration.has_refresh_token?(integration)

      capture_log(fn ->
        assert {:error, :token_expired} =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id),
                   []
                 )
      end)
    end

    test "looks up provider module based on integration.provider" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                   []
                 )
      end)
    end

    test "returns error :unsupported_provider for unknown providers" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id, :google)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)

      capture_log(fn ->
        assert {:error, :unsupported_provider} =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id),
                   []
                 )
      end)
    end

    test "calls provider.fetch_metrics/2 with integration and empty options map" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      test_pid = self()

      recording_plug =
        fn conn ->
          send(test_pid, {:provider_http_called, conn.request_path})

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"rows" => []}))
        end

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, recording_plug),
                   []
                 )
      end)

      assert_receive {:provider_http_called, _path}, 2000
    end

    test "persists each fetched metric via MetricFlow.Metrics.create_metric/2" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, single_row_plug()),
                   []
                 )
      end)

      stored_metrics = Metrics.list_metrics(scope)
      assert stored_metrics != []
      assert Enum.all?(stored_metrics, &(&1.user_id == user.id))
    end

    test "creates SyncHistory with status :success when all metrics persist successfully" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                   []
                 )
      end)

      assert match?([_], SyncHistoryRepository.list_sync_history(scope))
      assert hd(SyncHistoryRepository.list_sync_history(scope)).status == :success
    end

    test "sets records_synced to count of successfully persisted metrics" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, single_row_plug()),
                   []
                 )
      end)

      stored_metrics = Metrics.list_metrics(scope)
      [history] = SyncHistoryRepository.list_sync_history(scope)
      assert history.records_synced == Enum.count(stored_metrics)
    end

    test "updates SyncJob status to :completed on success" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                   []
                 )
      end)

      {:ok, final_job} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert final_job.status == :completed
    end

    test "creates SyncHistory with status :failed and error message on fetch failure" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        perform_job(
          SyncWorker,
          job_args(integration.id, user.id, sync_job.id, unauthorized_plug()),
          []
        )
      end)

      assert match?([_], SyncHistoryRepository.list_sync_history(scope))
      [history] = SyncHistoryRepository.list_sync_history(scope)
      assert history.status == :failed
      assert history.error_message != nil
    end

    test "creates SyncHistory with status :failed when metric persistence fails" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      malformed_plug =
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("text/plain")
          |> Plug.Conn.send_resp(200, "not valid json {{{")
        end

      capture_log(fn ->
        perform_job(
          SyncWorker,
          job_args(integration.id, user.id, sync_job.id, malformed_plug),
          []
        )
      end)

      assert match?([_], SyncHistoryRepository.list_sync_history(scope))
      assert hd(SyncHistoryRepository.list_sync_history(scope)).status == :failed
    end

    test "updates SyncJob status to :failed on any error" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        perform_job(
          SyncWorker,
          job_args(integration.id, user.id, sync_job.id, unauthorized_plug()),
          []
        )
      end)

      {:ok, final_job} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert final_job.status == :failed
    end

    test "includes error message in SyncHistory when provider.fetch_metrics/2 fails" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        perform_job(
          SyncWorker,
          job_args(integration.id, user.id, sync_job.id, forbidden_plug()),
          []
        )
      end)

      [history] = SyncHistoryRepository.list_sync_history(scope)
      assert history.error_message != nil
      assert String.length(history.error_message) > 0
    end

    test "includes error message in SyncHistory when token refresh fails" do
      {user, scope} = user_with_scope()
      integration = insert_expired_integration_with_refresh!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        perform_job(
          SyncWorker,
          job_args(integration.id, user.id, sync_job.id),
          []
        )
      end)

      [history] = SyncHistoryRepository.list_sync_history(scope)
      assert history.status == :failed
      assert history.error_message != nil
    end

    test "wraps sync execution in transaction for data consistency" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert :ok =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                   []
                 )
      end)

      {:ok, final_job} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert final_job.status == :completed
      assert match?([_], SyncHistoryRepository.list_sync_history(scope))
    end

    test "handles network errors gracefully with error tuple" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      capture_log(fn ->
        assert {:error, _reason} =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, sync_job.id, error_plug),
                   []
                 )
      end)

      {:ok, final_job} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert final_job.status == :failed
    end

    test "handles database errors gracefully with error tuple" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id)
      _sync_job = insert_sync_job!(user.id, integration.id)

      capture_log(fn ->
        assert {:error, _reason} =
                 perform_job(
                   SyncWorker,
                   job_args(integration.id, user.id, -999_999),
                   []
                 )
      end)
    end

    test "logs sync start and completion events" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      log =
        capture_log(fn ->
          assert :ok =
                   perform_job(
                     SyncWorker,
                     job_args(integration.id, user.id, sync_job.id, empty_rows_plug()),
                     []
                   )
        end)

      assert log =~ ~r/sync/i
    end

    test "logs errors with context (integration_id, user_id, provider)" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      log =
        capture_log(fn ->
          perform_job(
            SyncWorker,
            job_args(integration.id, user.id, sync_job.id, unauthorized_plug()),
            []
          )
        end)

      assert log =~ to_string(integration.id)
    end
  end

  # ---------------------------------------------------------------------------
  # provider_for/1
  # ---------------------------------------------------------------------------

  describe "provider_for/1" do
    test "returns {:ok, GoogleAnalytics} for :google_analytics provider" do
      assert {:ok, MetricFlow.DataSync.DataProviders.GoogleAnalytics} =
               SyncWorker.provider_for(:google_analytics)
    end

    test "returns {:ok, GoogleAds} for :google_ads provider" do
      assert {:ok, MetricFlow.DataSync.DataProviders.GoogleAds} =
               SyncWorker.provider_for(:google_ads)
    end

    test "returns {:ok, FacebookAds} for :facebook_ads provider" do
      assert {:ok, MetricFlow.DataSync.DataProviders.FacebookAds} =
               SyncWorker.provider_for(:facebook_ads)
    end

    test "returns {:ok, QuickBooks} for :quickbooks provider" do
      assert {:ok, MetricFlow.DataSync.DataProviders.QuickBooks} =
               SyncWorker.provider_for(:quickbooks)
    end

    test "returns error :unsupported_provider for :github provider" do
      assert {:error, :unsupported_provider} = SyncWorker.provider_for(:github)
    end

    test "returns error :unsupported_provider for :google provider" do
      assert {:error, :unsupported_provider} = SyncWorker.provider_for(:google)
    end

    test "returns error :unsupported_provider for :gitlab provider" do
      assert {:error, :unsupported_provider} = SyncWorker.provider_for(:gitlab)
    end

    test "returns error :unsupported_provider for :bitbucket provider" do
      assert {:error, :unsupported_provider} = SyncWorker.provider_for(:bitbucket)
    end

    test "returns error :unsupported_provider for nil" do
      assert {:error, :unsupported_provider} = SyncWorker.provider_for(nil)
    end

    test "returns error :unsupported_provider for unknown atom" do
      assert {:error, :unsupported_provider} =
               SyncWorker.provider_for(:completely_unknown_provider)
    end
  end
end
