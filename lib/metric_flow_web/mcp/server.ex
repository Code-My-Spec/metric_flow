defmodule MetricFlowWeb.MCP.Server do
  @moduledoc """
  MCP server at `/mcp`: lets a user's own AI agent (Claude, ChatGPT, ...) set
  up and check data sources on every account the user can access. Clients
  connect by URL and sign in through MetricFlow's OAuth server
  (`MetricFlowWeb.OAuthController`); `MetricFlowWeb.Plugs.MCPAuth` assigns
  the token's user as `:mcp_user_id`.
  """
  use Anubis.Server, name: "metricflow", version: "1.0.0", capabilities: [:tools]

  alias Anubis.Server.Frame
  alias Anubis.Server.Response
  alias MetricFlow.Onboarding.Tools
  alias MetricFlow.Users

  @impl true
  def server_instructions,
    do:
      "Set up and check data sources for the MetricFlow accounts this user can access. " <>
        "Start with list_accounts, then get_setup_status with an account_id. " <>
        "Connecting needs the customer to open the link from get_connect_link."

  @impl true
  def init(_client_info, frame) do
    # Our specs are plain JSON Schema, which Anubis's Peri-based validator
    # doesn't read. Register, then publish the JSON Schema verbatim and leave
    # argument checking to `Tools.call/4` (shared with the in-app agent).
    frame =
      Enum.reduce(Tools.specs(:mcp), frame, fn spec, frame ->
        frame = Frame.register_tool(frame, spec.name, description: spec.description)

        update_in(frame.tools[spec.name], fn tool ->
          %{tool | input_schema: json_schema(spec.input_schema), validate_input: &{:ok, &1}}
        end)
      end)

    {:ok, frame}
  end

  @impl true
  def handle_tool_call(name, args, frame) do
    ctx =
      case frame.assigns do
        %{mcp_user_id: id} when is_integer(id) -> %{user: Users.get_user!(id)}
        _ -> %{}
      end

    response =
      case Tools.call(:mcp, name, stringify(args), ctx) do
        {:ok, data} -> Response.json(Response.tool(), data)
        {:error, message} -> Response.error(Response.tool(), message)
      end

    {:reply, response, frame}
  end

  defp json_schema(schema), do: Jason.decode!(Jason.encode!(schema))

  defp stringify(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), stringify(v)} end)

  defp stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)
  defp stringify(v), do: v
end
