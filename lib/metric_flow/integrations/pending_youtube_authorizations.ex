defmodule MetricFlow.Integrations.PendingYouTubeAuthorizations do
  @moduledoc "Short-lived server-side credentials awaiting channel selection."
  use GenServer

  @ttl_seconds 600

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def put(user_id, account_id, credentials) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    :ok = GenServer.call(__MODULE__, {:put, token, user_id, account_id, credentials})
    token
  end

  def get(token, user_id, account_id),
    do: GenServer.call(__MODULE__, {:get, token, user_id, account_id})

  def delete(token, user_id, account_id),
    do: GenServer.call(__MODULE__, {:delete, token, user_id, account_id})

  @impl true
  def init(state) do
    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_call({:put, token, user_id, account_id, credentials}, _from, state) do
    entry = {user_id, account_id, credentials, now() + @ttl_seconds}
    {:reply, :ok, Map.put(state, token, entry)}
  end

  def handle_call({:get, token, user_id, account_id}, _from, state) do
    case Map.get(state, token) do
      {^user_id, ^account_id, credentials, expires_at} ->
        if expires_at > now() do
          {:reply, {:ok, credentials}, state}
        else
          {:reply, {:error, :expired}, Map.delete(state, token)}
        end

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:delete, token, user_id, account_id}, _from, state) do
    state =
      case Map.get(state, token) do
        {^user_id, ^account_id, _, _} -> Map.delete(state, token)
        _ -> state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cutoff = now()
    state = Map.reject(state, fn {_, {_, _, _, expires_at}} -> expires_at <= cutoff end)
    schedule_cleanup()
    {:noreply, state}
  end

  defp now, do: System.monotonic_time(:second)
  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, 60_000)
end
