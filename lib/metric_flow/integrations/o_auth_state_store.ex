defmodule MetricFlow.Integrations.OAuthStateStore do
  @moduledoc """
  Server-side ETS-backed store for OAuth session params, keyed by the state token.

  Assent generates a random `state` parameter during `authorize_url/1` and
  returns it in `session_params`. The OAuth provider echoes this state back
  in the callback query string. This module stores the session_params in
  ETS so the callback can retrieve them by state value — avoiding any
  reliance on cookies or the Phoenix session, which can be lost when
  reverse proxies strip Set-Cookie headers from 302 redirects.

  Entries expire after 5 minutes and are cleaned up periodically.
  Fetch is consume-once: retrieving a state entry deletes it immediately.
  """

  use GenServer

  @table :oauth_state_store
  @ttl_seconds 300

  @doc "Starts the OAuthStateStore GenServer and registers it under its module name."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  Stores `session_params` in ETS keyed by the OAuth `state` string.

  Records the current wall-clock timestamp for TTL enforcement.
  """
  @spec store(String.t(), map()) :: :ok
  def store(state, session_params) when is_binary(state) do
    :ets.insert(@table, {state, session_params, System.system_time(:second)})
    :ok
  end

  @doc """
  Retrieves and atomically removes the `session_params` for the given `state`.

  Returns `:error` if the entry does not exist or has exceeded the 5-minute TTL.
  Each state may only be fetched once (consume-once semantics).
  """
  @spec fetch(String.t()) :: {:ok, map()} | :error
  def fetch(state) when is_binary(state) do
    case :ets.lookup(@table, state) do
      [{^state, session_params, ts}] ->
        :ets.delete(@table, state)

        if System.system_time(:second) - ts <= @ttl_seconds,
          do: {:ok, session_params},
          else: :error

      [] ->
        :error
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cutoff = System.system_time(:second) - @ttl_seconds
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, 60_000)
end
