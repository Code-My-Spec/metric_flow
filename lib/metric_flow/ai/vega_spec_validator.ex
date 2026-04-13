defmodule MetricFlow.Ai.VegaSpecValidator do
  @moduledoc """
  Validates Vega-Lite specifications against the official v5 JSON Schema.

  Uses JSV (JSON Schema Validator) with the schema from
  `priv/vega_lite_v5_schema.json` (draft-07). The compiled schema is cached
  in a persistent_term at application start to avoid the ~200ms build cost
  on every validation.

  This provides structural validation — wrong types, unknown properties,
  missing required fields. Semantic validation (bad channel/mark combos,
  encoding logic) happens at compile/render time in the browser via
  vegaEmbed.
  """

  @schema_path "priv/vega_lite_v5_schema.json"
  @pt_key {__MODULE__, :compiled_schema}

  @doc """
  Initialise the compiled schema and store it in persistent_term.

  Call this once at application start (e.g. from Application.start/2).
  """
  @spec init() :: :ok
  def init do
    schema =
      :metric_flow
      |> :code.priv_dir()
      |> Path.join("vega_lite_v5_schema.json")
      |> File.read!()
      |> Jason.decode!()

    {:ok, root} = JSV.build(schema)
    :persistent_term.put(@pt_key, root)
    :ok
  end

  @doc """
  Validates a Vega-Lite spec map against the v5 JSON Schema.

  Returns `{:ok, spec}` if valid, `{:error, errors}` with a list of
  human-readable error strings if invalid.

  ## Examples

      iex> VegaSpecValidator.validate(%{"$schema" => "...", "mark" => "bar", ...})
      {:ok, spec}

      iex> VegaSpecValidator.validate(%{"foo" => "bar"})
      {:error, ["..."]}
  """
  @spec validate(map()) :: {:ok, map()} | {:error, [String.t()]}
  def validate(spec) when is_map(spec) do
    root = :persistent_term.get(@pt_key)

    case JSV.validate(spec, root) do
      {:ok, _casted} ->
        {:ok, spec}

      {:error, %JSV.ValidationError{errors: errors}} ->
        {:error, format_errors(errors)}
    end
  end

  def validate(_), do: {:error, ["Spec must be a JSON object"]}

  @doc """
  Returns true if the spec is structurally valid against the Vega-Lite schema.
  """
  @spec valid?(map()) :: boolean()
  def valid?(spec), do: match?({:ok, _}, validate(spec))

  # Format JSV errors into readable strings.
  # JSV errors can be deeply nested due to anyOf/oneOf; we take the top-level
  # kind and path to keep messages actionable without overwhelming the user.
  defp format_errors(errors) do
    Enum.map(errors, fn
      %{kind: kind, args: args} ->
        path = format_path(args)
        "#{path}#{kind}"

      other ->
        inspect(other)
    end)
  end

  defp format_path(args) when is_list(args) do
    case Keyword.get(args, :pointer) do
      nil -> ""
      [] -> "/ "
      parts when is_list(parts) -> Enum.join(parts, "/") <> " "
      _ -> ""
    end
  end

  defp format_path(_), do: ""
end
