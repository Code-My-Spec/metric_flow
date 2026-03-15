# MetricFlow.Integrations.OAuthStateStore

Server-side ETS-backed store for OAuth session params, keyed by the OAuth `state` token. Runs as a named GenServer that owns the ETS table and periodically purges expired entries. Avoids any reliance on cookies or the Phoenix session, which can be stripped by reverse proxies during 302 redirects.

## Functions

### start_link/1

Starts the OAuthStateStore GenServer and registers it under its module name.

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

**Process**:
1. Call `GenServer.start_link/3` with the module, `nil` init arg, and `name: __MODULE__`
2. Return the result of `start_link`

**Test Assertions**:
- Starts successfully under a supervisor
- Registers the process under the module name

### store/2

Stores `session_params` in ETS keyed by the OAuth `state` string, recording the current wall-clock timestamp for TTL enforcement.

```elixir
@spec store(String.t(), map()) :: :ok
```

**Process**:
1. Guard: `state` must be a binary
2. Insert `{state, session_params, System.system_time(:second)}` into the `:oauth_state_store` ETS table
3. Return `:ok`

**Test Assertions**:
- Returns `:ok` for a valid binary state and a map of session params
- Overwrites an existing entry when called twice with the same state
- Raises `ArgumentError` when state is not a binary

### fetch/1

Retrieves and atomically removes the `session_params` associated with the given `state`. Returns `:error` if the entry does not exist or has exceeded the 5-minute TTL.

```elixir
@spec fetch(String.t()) :: {:ok, map()} | :error
```

**Process**:
1. Guard: `state` must be a binary
2. Look up the state in ETS with `:ets.lookup/2`
3. If no entry is found, return `:error`
4. If an entry is found, delete it immediately from ETS (consume-once semantics)
5. Compare the stored timestamp against `System.system_time(:second)` using the 300-second TTL
6. Return `{:ok, session_params}` if within TTL, otherwise `:error`

**Test Assertions**:
- Returns `{:ok, session_params}` immediately after a matching `store/2` call
- Returns `:error` for an unknown state
- Returns `:error` for a state stored more than 300 seconds ago
- Calling `fetch/1` a second time for the same state returns `:error` (consume-once)
- Returns `:error` when state is not a binary

## Dependencies

- GenServer
