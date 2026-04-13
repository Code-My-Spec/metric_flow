defmodule MetricFlow.Ai.VizChat do
  @moduledoc """
  Conversational visualization agent backed by Anubis MCP tool components.

  Bridges between ReqLLM (Anthropic API) and Anubis tool definitions. The model
  can update the Vega-Lite spec, browse documentation, and query available metrics.

  Multi-turn conversation context is maintained by passing a `ReqLLM.Context`
  struct between calls — the full tool-call/tool-result exchanges are preserved
  so the model has complete history.
  """

  require Logger

  alias Anubis.Server.Frame
  alias MetricFlow.Ai.VizTools

  @chat_model "anthropic:claude-sonnet-4-5"

  @tool_modules [
    VizTools.UpdateSpec,
    VizTools.ListDocs,
    VizTools.ReadDoc,
    VizTools.SearchDocs,
    VizTools.QueryMetrics
  ]

  @max_tool_depth 5

  @doc """
  Send a message in the visualization chat.

  ## Parameters

    * `context` — a `ReqLLM.Context` struct (or nil for first message)
    * `user_message` — the new user message text
    * `opts` — keyword list:
      - `:metric_names` — list of metric name strings available to the account
      - `:current_spec` — current Vega-Lite spec map (or nil)
      - `:system_prompt` — override the default system prompt
      - `:req_http_options` — forwarded to ReqLLM for test cassettes

  ## Returns

    * `{:ok, %{text: String.t(), spec: map() | nil, context: ReqLLM.Context.t()}}`
    * `{:error, term()}`
  """
  @spec send_message(ReqLLM.Context.t() | nil, String.t(), keyword()) ::
          {:ok, %{text: String.t(), spec: map() | nil, context: ReqLLM.Context.t()}}
          | {:error, term()}
  def send_message(context, user_message, opts \\ []) do
    {metric_names, opts} = Keyword.pop(opts, :metric_names, [])
    {current_spec, opts} = Keyword.pop(opts, :current_spec)
    {system_prompt, opts} = Keyword.pop(opts, :system_prompt)

    system_prompt = system_prompt || build_system_prompt(current_spec)
    frame = %Frame{assigns: %{metric_names: metric_names}}

    # Build ReqLLM tools from Anubis component schemas
    req_tools = build_req_tools()

    # Build or extend the context with the new user message
    context = build_context(context, user_message, system_prompt)

    merged_opts =
      Keyword.merge(opts,
        system_prompt: system_prompt,
        tools: req_tools,
        tool_choice: :auto
      )

    run_tool_loop(context, frame, merged_opts, _depth = 0, _spec = nil)
  end

  # ---------------------------------------------------------------------------
  # Context management
  # ---------------------------------------------------------------------------

  defp build_context(nil, user_message, _system_prompt) do
    ReqLLM.Context.new([ReqLLM.Context.user(user_message)])
  end

  defp build_context(%ReqLLM.Context{} = ctx, user_message, _system_prompt) do
    ReqLLM.Context.append(ctx, ReqLLM.Context.user(user_message))
  end

  # ---------------------------------------------------------------------------
  # Agentic tool loop
  # ---------------------------------------------------------------------------

  defp run_tool_loop(context, _frame, _opts, depth, spec) when depth >= @max_tool_depth do
    {:ok,
     %{
       text: "I've completed my research. Let me know if you'd like me to try again.",
       spec: spec,
       context: context
     }}
  end

  defp run_tool_loop(context, frame, opts, depth, accumulated_spec) do
    case ReqLLM.generate_text(@chat_model, context, opts) do
      {:ok, response} ->
        classified = ReqLLM.Response.classify(response)
        text = classified.text || ""
        tool_calls = classified.tool_calls

        if tool_calls == [] do
          # No tool calls — conversation turn complete
          updated_context =
            ReqLLM.Context.append(context, ReqLLM.Context.assistant(text))

          {:ok, %{text: text, spec: accumulated_spec, context: updated_context}}
        else
          # Build assistant message with tool calls
          assistant_msg = ReqLLM.Context.assistant(text, tool_calls: tool_calls)
          context = ReqLLM.Context.append(context, assistant_msg)

          # Execute tools — frame.assigns.validated_spec is set by UpdateSpec
          # on successful validation, cleared on failure
          frame = put_in(frame.assigns[:validated_spec], nil)
          {context, frame} = execute_tools(context, tool_calls, frame)

          validated_spec = frame.assigns[:validated_spec]

          if validated_spec do
            # Tool validated and accepted a new spec — show it to the user
            {:ok, %{text: text, spec: validated_spec, context: context}}
          else
            # No valid spec yet (other tools, or validation failed and errors
            # were sent back to the LLM) — continue so the model can fix it
            run_tool_loop(context, frame, opts, depth + 1, accumulated_spec)
          end
        end

      {:error, reason} ->
        Logger.error("VizChat error at depth #{depth}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Tool execution via Anubis components
  # ---------------------------------------------------------------------------

  defp execute_tools(context, tool_calls, frame) do
    Enum.reduce(tool_calls, {context, frame}, fn tool_call, {ctx, frm} ->
      name = tool_call.name
      id = tool_call.id
      args = tool_call.arguments

      {result_text, frm} = execute_anubis_tool(name, args, frm)
      tool_result_msg = ReqLLM.Context.tool_result(id, name, result_text)
      {ReqLLM.Context.append(ctx, tool_result_msg), frm}
    end)
  end

  defp execute_anubis_tool(name, args, frame) do
    case find_tool_module(name) do
      nil ->
        {"Tool '#{name}' not found.", frame}

      module ->
        validated_args = validate_tool_input(module, args)

        case module.execute(validated_args, frame) do
          {:reply, %{content: content}, updated_frame} ->
            {extract_text_from_response(content), updated_frame}

          {:error, _error, updated_frame} ->
            {"Tool execution failed.", updated_frame}
        end
    end
  end

  defp validate_tool_input(module, args) when is_map(args) do
    # Anubis components expect atom keys; API sends string keys
    atom_args =
      Map.new(args, fn {k, v} ->
        key = if is_binary(k), do: String.to_existing_atom(k), else: k
        {key, v}
      end)

    case module.mcp_schema(atom_args) do
      {:ok, validated} -> validated
      {:error, _} -> atom_args
    end
  end

  defp extract_text_from_response(content) when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", & &1["text"])
  end

  defp extract_text_from_response(_), do: ""

  defp find_tool_module(name) do
    Enum.find(@tool_modules, fn mod ->
      tool_name(mod) == name
    end)
  end

  # ---------------------------------------------------------------------------
  # Tool schema conversion (Anubis → ReqLLM)
  # ---------------------------------------------------------------------------

  defp build_req_tools do
    Enum.map(@tool_modules, fn mod ->
      {:ok, tool} =
        ReqLLM.Tool.new(
          name: tool_name(mod),
          description: mod.__description__() || "",
          parameter_schema: convert_anubis_schema_to_nimble(mod.__mcp_raw_schema__()),
          # Callback not used — we execute via Anubis components directly
          callback: fn _args -> {:ok, "executed via anubis"} end
        )

      tool
    end)
  end

  # Convert Anubis field DSL to NimbleOptions-compatible schema for ReqLLM.Tool
  defp convert_anubis_schema_to_nimble(schema) when is_map(schema) do
    Enum.map(schema, fn {field_name, {:mcp_field, type, opts}} ->
      {required, base_type} =
        case type do
          {:required, t} -> {true, t}
          t -> {false, t}
        end

      nimble_type =
        case base_type do
          :string -> :string
          :integer -> :integer
          :number -> :float
          :boolean -> :boolean
          _ -> :string
        end

      nimble_opts =
        [type: nimble_type, required: required] ++
          if(opts[:description], do: [doc: opts[:description]], else: [])

      {field_name, nimble_opts}
    end)
  end

  # Derive a tool name from the module (e.g. VizTools.UpdateSpec → "update_spec")
  defp tool_name(mod) do
    mod
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  # ---------------------------------------------------------------------------
  # System prompt
  # ---------------------------------------------------------------------------

  @base_system_prompt """
  You are a data visualization assistant for a marketing analytics platform.
  You help users create and refine Vega-Lite v5 chart specifications.

  You have access to tools for:
  - Updating the Vega-Lite spec (creates/modifies the chart)
  - Browsing Vega-Lite documentation (list_docs, read_doc, search_docs)
  - Querying available metrics for the account

  IMPORTANT conventions:
  - Always use named data sources: {"data": {"name": "metricName"}}
  - Never embed data values — they are injected at render time
  - For multiple metrics, use "layer" with separate named data sources per layer
  - Include "$schema": "https://vega.github.io/schema/vega-lite/v5.json"

  When the user asks you to create or change a chart, call the update_spec tool.
  When you need to verify Vega-Lite syntax, browse the docs first.
  When you need to know what data is available, use query_metrics.

  Be conversational — explain what you're doing, answer questions, and suggest
  improvements. Not every message needs a spec update.
  """

  defp build_system_prompt(nil) do
    String.trim(@base_system_prompt) <>
      "\n\nNo chart exists yet. When the user asks for a visualization, " <>
      "create one by calling update_spec."
  end

  defp build_system_prompt(current_spec) do
    String.trim(@base_system_prompt) <>
      "\n\nCurrent Vega-Lite spec:\n```json\n" <>
      Jason.encode!(current_spec, pretty: true) <>
      "\n```\nWhen editing, pass the COMPLETE updated spec to update_spec."
  end
end
