# MetricFlow.Dashboards.QueryBuilder

Pure module that builds structured query params from filter inputs (date range, platforms, metric names)

## Type

module

## Dependencies

- None

## Functions

### build/1

Builds a `%{date_range, provider, metric_names}` query params map from a keyword list of filter options. All fields default to nil or empty list when not provided. Normalizes the `:google` platform into `[:google_analytics, :google_ads]`. Returns the query params map directly (no tagged tuple, since this is a pure builder with no validation failures).

```elixir
@spec build(keyword()) :: %{date_range: {Date.t(), Date.t()} | nil, provider: atom() | list(atom()) | nil, metric_names: list(String.t())}
```

**Options**:
- `:date_range` — `{start_date, end_date}` tuple or nil
- `:platform` — atom, list of atoms, or nil; `:google` expands to `[:google_analytics, :google_ads]`; empty list normalizes to nil
- `:metric_names` — list of strings or nil (defaults to [])

**Test Assertions**:
- returns a query_params map with nil date_range by default
- returns a query_params map with nil provider by default
- returns a query_params map with empty metric_names by default
- sets date_range from :date_range option
- sets provider from :platform atom option
- expands :google platform into [:google_analytics, :google_ads]
- sets provider from a list of platform atoms
- sets nil provider when :platform is nil
- sets nil provider when :platform is an empty list
- sets metric_names from :metric_names option
- accepts all options together

### to_keyword/1

Converts a query params map into a keyword list, omitting keys whose values are nil or empty. The resulting keyword list is suitable for passing to `Metrics` context query functions.

```elixir
@spec to_keyword(%{date_range: term(), provider: term(), metric_names: list()}) :: keyword()
```

**Test Assertions**:
- omits :date_range key when date_range is nil
- includes :date_range key when date_range is set
- omits :provider key when provider is nil
- includes :provider key when provider is an atom
- includes :provider key when provider is a list of atoms
- omits :metric_names key when metric_names is empty
- includes :metric_names key when metric_names is non-empty
- returns an empty keyword list when all fields are nil or empty

### has_date_range?/1

Returns true when the query params map has a non-nil date_range value, false otherwise.

```elixir
@spec has_date_range?(%{date_range: term()}) :: boolean()
```

**Test Assertions**:
- returns true when date_range is a {Date, Date} tuple
- returns false when date_range is nil

### has_platform_filter?/1

Returns true when the query params map has a non-nil, non-empty provider value, false otherwise.

```elixir
@spec has_platform_filter?(%{provider: term()}) :: boolean()
```

**Test Assertions**:
- returns false when provider is nil
- returns false when provider is an empty list
- returns true when provider is an atom
- returns true when provider is a list of atoms

### has_metric_name_filter?/1

Returns true when the query params map has a non-empty metric_names list, false otherwise.

```elixir
@spec has_metric_name_filter?(%{metric_names: list()}) :: boolean()
```

**Test Assertions**:
- returns false when metric_names is empty
- returns true when metric_names is non-empty

### merge/2

Merges new filter opts into an existing query params map. Accepts the same `:date_range`, `:platform`, and `:metric_names` options as `build/1`. Applies the same normalization rules (`:google` expansion, empty list to nil). Unknown keys are ignored. Returns the updated query params map.

```elixir
@spec merge(%{date_range: term(), provider: term(), metric_names: list()}, keyword()) :: %{date_range: term(), provider: term(), metric_names: list()}
```

**Test Assertions**:
- updates date_range from opts
- updates provider from :platform opt
- expands :google platform during merge
- updates metric_names from opts
- ignores unknown option keys
- preserves unchanged fields
