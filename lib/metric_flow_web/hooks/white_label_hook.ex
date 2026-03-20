defmodule MetricFlowWeb.WhiteLabelHook do
  @moduledoc """
  LiveView on_mount hook that loads white-label configuration.

  First checks the session for subdomain-based white-label config (set by the
  WhiteLabel plug). If none is found and the user is authenticated, falls back
  to checking whether the user's active account was originated by an agency
  with white-label config, and auto-applies it.
  """

  import Phoenix.Component, only: [assign: 3]

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies

  def on_mount(:load_white_label, _params, session, socket) do
    config = Map.get(session, "white_label_config")

    config =
      if is_nil(config) do
        maybe_originator_config(socket)
      else
        config
      end

    {:cont, assign(socket, :white_label_config, config)}
  end

  defp maybe_originator_config(socket) do
    case socket.assigns do
      %{current_scope: %{} = scope} ->
        case Accounts.list_accounts(scope) do
          [account | _] -> Agencies.get_originator_white_label_config(account.id)
          [] -> nil
        end

      _ ->
        nil
    end
  end
end
