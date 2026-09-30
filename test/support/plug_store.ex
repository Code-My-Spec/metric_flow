defmodule MetricFlowTest.PlugStore do
  @moduledoc """
  ETS-backed registry for test HTTP plug functions.

  Enables Oban workers to receive plug functions through job args even though
  Oban.Testing.perform_job/3 JSON-encodes and decodes all args (which would
  normally destroy function references).

  Usage:
  - When a function is JSON-encoded (via the JSON.Encoder for Function), it is
    stored in the ETS table and its key is returned as a string.
  - The SyncWorker checks if `http_plug` in args is a string key, looks it up
    here, and retrieves the original function.

  The ETS table is named :metric_flow_test_plug_store and is created lazily
  by ensure_table/0, which is safe to call multiple times.
  """

  @table :metric_flow_test_plug_store

  @doc """
  Ensures the ETS table exists. Safe to call multiple times.
  """
  @spec ensure_table() :: :ok
  def ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set])
        :ok

      _tid ->
        :ok
    end
  end

  @doc """
  Stores a plug function and returns a unique string key for retrieval.
  """
  @spec store(function()) :: String.t()
  def store(fun) when is_function(fun) do
    ensure_table()
    key = "__plug_ref_#{System.unique_integer([:positive])}"
    :ets.insert(@table, {key, fun})
    key
  end

  @doc """
  Retrieves a stored plug function by key.

  Returns {:ok, fun} when found, or {:error, :not_found} when the key does
  not exist in the store.
  """
  @spec fetch(String.t()) :: {:ok, function()} | {:error, :not_found}
  def fetch(key) when is_binary(key) do
    ensure_table()

    case :ets.lookup(@table, key) do
      [{^key, fun}] -> {:ok, fun}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns true if the string looks like a plug store key.
  """
  @spec plug_key?(term()) :: boolean()
  def plug_key?("__plug_ref_" <> _rest), do: true
  def plug_key?(_), do: false

  @doc """
  Registers a plug for a provider, for specs that trigger a sync through
  `DataSync.sync_integration/2` (a LiveView click) rather than calling a
  provider's `fetch_metrics/2` directly. A click can't pass a function
  through `render_click/1`, so `sync_integration/2` looks up a plug
  registered here (by provider) instead of one threaded through job args.
  """
  @spec put_provider_plug(atom(), function()) :: :ok
  def put_provider_plug(provider, fun) when is_atom(provider) and is_function(fun) do
    ensure_table()
    :ets.insert(@table, {{:provider_plug, provider}, fun})
    :ok
  end

  @doc """
  Retrieves a plug registered for a provider via `put_provider_plug/2`.
  """
  @spec get_provider_plug(atom()) :: {:ok, function()} | :error
  def get_provider_plug(provider) when is_atom(provider) do
    ensure_table()

    case :ets.lookup(@table, {:provider_plug, provider}) do
      [{_, fun}] -> {:ok, fun}
      [] -> :error
    end
  end
end

defimpl JSON.Encoder, for: Function do
  @doc """
  Encodes an anonymous function by storing it in the PlugStore and returning
  its registry key as a JSON string.

  This enables Oban.Testing.perform_job/3 (which JSON-encodes all job args)
  to round-trip plug functions for test-time HTTP interception in SyncWorker
  tests.
  """
  def encode(fun, encoder) do
    key = MetricFlowTest.PlugStore.store(fun)
    JSON.Encoder.encode(key, encoder)
  end
end
