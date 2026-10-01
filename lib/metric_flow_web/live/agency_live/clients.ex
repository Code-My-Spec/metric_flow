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
        </:actions>
      </.header>

      <div class="mt-8 space-y-6">
        <div :if={@referral_url} class="card bg-base-100 shadow mf-card" data-role="referral-link-card">
          <div class="card-body">
            <h2 class="card-title text-base">Your Referral Link</h2>
            <p class="text-sm text-base-content/60">
              Share this link with a new client. When they register through it, they're
              automatically connected to your agency and marked as originated by you.
            </p>
            <input
              type="text"
              readonly
              value={@referral_url}
              data-role="referral-link-input"
              class="input w-full font-mono text-sm mt-2"
              onclick="this.select()"
            />
          </div>
        </div>

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

    referral_url =
      account_id &&
        url(~p"/users/register?ref=#{Agencies.generate_referral_token(account_id)}")

    socket =
      socket
      |> assign(:grants, grants)
      |> assign(:referral_url, referral_url)

    {:ok, socket}
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
