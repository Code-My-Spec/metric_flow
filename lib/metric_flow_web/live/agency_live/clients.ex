defmodule MetricFlowWeb.AgencyLive.Clients do
  @moduledoc """
  Agency client management page.

  Lists all client accounts the agency has access to, showing access level
  and origination status for each.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Agencies

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
      active_account_type={assigns[:active_account_type]}
    >
    <div class="mx-auto">
      <.header>
        Clients
        <:subtitle>Client accounts managed by your agency</:subtitle>
        <:actions>
          <.link navigate={~p"/app/help/account-origination"} class="btn btn-ghost btn-sm">
            How does origination work?
          </.link>
          <button phx-click="generate_referral_link" class="btn btn-primary btn-sm">
            Add Client
          </button>
        </:actions>
      </.header>

      <div :if={@referral_url} class="alert mt-4">
        <div class="w-full">
          <p class="font-medium mb-2">
            Share this link with your client — signing up through it connects them to your agency automatically.
          </p>
          <input
            type="text"
            readonly
            value={@referral_url}
            onclick="this.select()"
            class="input input-bordered w-full font-mono text-sm"
          />
        </div>
      </div>

      <div class="mt-8 space-y-6">
        <div class="stats shadow w-full">
          <div class="stat">
            <div class="stat-title">Total Clients</div>
            <div class="stat-value">{length(@grants)}</div>
          </div>
          <div class="stat">
            <div class="stat-title">Originated</div>
            <div class="stat-value">{Enum.count(@grants, &(&1.origination_status == :originator))}</div>
          </div>
        </div>

        <div :if={@grants == []} class="text-base-content/60 text-sm">
          No client accounts yet.
        </div>

        <div class="overflow-x-auto">
          <table :if={@grants != []} class="table w-full">
            <thead>
              <tr>
                <th>Client</th>
                <th>Slug</th>
                <th>Access Level</th>
                <th>Origination</th>
                <th>Since</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={grant <- @grants} class="hover">
                <td class="font-medium">{grant.client_account.name}</td>
                <td class="font-mono text-sm text-base-content/60">{grant.client_account.slug}</td>
                <td>
                  <span class={access_level_badge_class(grant.access_level)}>
                    {access_level_label(grant.access_level)}
                  </span>
                </td>
                <td>
                  <span class={origination_badge_class(grant.origination_status)}>
                    {origination_label(grant.origination_status)}
                  </span>
                </td>
                <td class="text-sm text-base-content/60">{format_date(grant.inserted_at)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns[:active_account_id]

    grants =
      case account_id && Agencies.list_agency_client_accounts(scope, account_id) do
        {:error, _} -> []
        nil -> []
        grants -> grants
      end

    socket =
      socket
      |> assign(:grants, grants)
      |> assign(:referral_url, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("generate_referral_link", _params, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns[:active_account_id]

    case account_id && Agencies.generate_referral_link(scope, account_id) do
      {:ok, token} ->
        url = MetricFlowWeb.Endpoint.url() <> ~p"/users/register?ref=#{token}"
        {:noreply, assign(socket, :referral_url, url)}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to generate a referral link")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to generate a referral link")}
    end
  end

  defp access_level_label(:read_only), do: "Read Only"
  defp access_level_label(:account_manager), do: "Account Manager"
  defp access_level_label(:admin), do: "Admin"
  defp access_level_label(_), do: "Unknown"

  defp access_level_badge_class(:admin), do: "badge badge-primary"
  defp access_level_badge_class(:account_manager), do: "badge badge-secondary"
  defp access_level_badge_class(_), do: "badge badge-ghost"

  defp origination_label(:originator), do: "Originated"
  defp origination_label(:invited), do: "Invited"
  defp origination_label(_), do: "Unknown"

  defp origination_badge_class(:originator), do: "badge badge-accent"
  defp origination_badge_class(_), do: "badge badge-ghost"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y")
  end

  defp format_date(_), do: ""
end
