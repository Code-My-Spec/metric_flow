defmodule MetricFlow.Integrations.OAuthStateStoreTest do
  use ExUnit.Case, async: false

  alias MetricFlow.Integrations.OAuthStateStore

  @table :oauth_state_store
  @ttl_seconds 300

  # ---------------------------------------------------------------------------
  # start_link/1
  # ---------------------------------------------------------------------------

  describe "start_link/1" do
    test "starts successfully and registers under its module name" do
      assert pid = Process.whereis(OAuthStateStore)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # store/2
  # ---------------------------------------------------------------------------

  describe "store/2" do
    test "returns :ok for a valid binary state and a map of session params" do
      state = unique_state()
      assert :ok = OAuthStateStore.store(state, %{token: "abc"})
    end

    test "overwrites an existing entry when called twice with the same state" do
      state = unique_state()
      OAuthStateStore.store(state, %{token: "first"})
      OAuthStateStore.store(state, %{token: "second"})

      assert {:ok, %{token: "second"}} = OAuthStateStore.fetch(state)
    end

    test "raises ArgumentError when state is not a binary" do
      assert_raise FunctionClauseError, fn ->
        OAuthStateStore.store(12345, %{token: "abc"})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # fetch/1
  # ---------------------------------------------------------------------------

  describe "fetch/1" do
    test "returns {:ok, session_params} immediately after a matching store/2 call" do
      state = unique_state()
      session_params = %{token: "xyz", provider: "google"}

      OAuthStateStore.store(state, session_params)

      assert {:ok, ^session_params} = OAuthStateStore.fetch(state)
    end

    test "returns :error for an unknown state" do
      assert :error = OAuthStateStore.fetch("unknown-state-#{System.unique_integer()}")
    end

    test "returns :error for a state stored more than 300 seconds ago" do
      state = unique_state()
      stale_ts = System.system_time(:second) - (@ttl_seconds + 1)
      :ets.insert(@table, {state, %{token: "stale"}, stale_ts})

      assert :error = OAuthStateStore.fetch(state)
    end

    test "calling fetch/1 a second time for the same state returns :error (consume-once)" do
      state = unique_state()
      OAuthStateStore.store(state, %{token: "once"})

      assert {:ok, _} = OAuthStateStore.fetch(state)
      assert :error = OAuthStateStore.fetch(state)
    end

    test "returns :error when state is not a binary" do
      assert_raise FunctionClauseError, fn ->
        OAuthStateStore.fetch(42)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_state, do: "state-#{System.unique_integer([:positive, :monotonic])}"
end
