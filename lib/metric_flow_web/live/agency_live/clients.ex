defmodule MetricFlowWeb.AgencyLive.Clients do
  @moduledoc """
  Agency client management page.

  Lists each client the agency reports to and resells to as one card per
  client, with the client's name, data-source health and when their data
  was last synced, linking into that client's workspace. The one primary
  action on the page is inviting a new client via a referral link.
  """

  use MetricFlowWeb, :live_view

  import Ecto.Query

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

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
      <div class="mx-auto overflow-x-hidden">
        <.header>
          Clients
          <:subtitle>The clients you report to and resell to.</:subtitle>
        </.header>

        <div class="mt-6 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <p class="min-w-0 text-sm text-base-content/70 break-words">
            Invite a client to join your agency. When they sign up through your referral link, their account connects to yours automatically.
          </p>
          <button
            type="button"
            phx-click="generate_referral_link"
            data-role="invite-client"
            class="btn-brand-gradient rounded-box px-4 py-2 w-full sm:w-auto"
          >
            Invite a client
          </button>
        </div>

        <div
          :if={@referral_url}
          data-role="referral-link"
          class="mt-4 rounded-box border border-neutral bg-base-200 p-4"
        >
          <p class="mb-2 font-semibold text-base-content">
            Share this link with your client — signing up through it connects them to your agency automatically.
          </p>
          <input
            type="text"
            readonly
            value={@referral_url}
            onclick="this.select()"
            class="w-full rounded-box border border-neutral bg-base-100 px-3 py-2 font-mono text-sm text-base-content"
          />
          <.link
            navigate={~p"/app/help/account-origination"}
            class="mt-3 inline-block text-xs text-base-content/70 underline"
          >
            How account connections work
          </.link>
        </div>

        <section
          :if={@grants == []}
          data-role="clients-empty-state"
          class="mt-6 rounded-box border border-neutral bg-base-200 p-6 text-center"
        >
          <h2 class="text-base font-semibold text-base-content">No clients yet</h2>
          <p class="mt-2 text-sm text-base-content/70 break-words">
            Click <span class="font-semibold text-base-content">Invite a client</span>
            above to copy a referral link and send it to your first client.
            When they sign up through the link, their account appears here
            with its data health and last activity.
          </p>
        </section>

        <ul :if={@grants != []} class="mt-6 flex flex-col gap-3">
          <li
            :for={grant <- @grants}
            data-role="client-card"
            data-client-account-id={grant.client_account_id}
            class="rounded-box border border-neutral bg-base-200"
          >
            <button
              type="button"
              phx-click="open_client"
              phx-value-account_id={grant.client_account_id}
              class="flex w-full min-w-0 flex-col gap-3 rounded-box px-4 py-4 text-left hover:bg-base-300"
            >
              <div class="flex min-w-0 flex-wrap items-start justify-between gap-2">
                <div class="min-w-0 flex-1">
                  <div class="font-semibold text-base-content break-words">
                    {grant.client_account.name}
                  </div>
                  <div class="font-mono text-xs text-base-content/60 break-all">
                    {grant.client_account.slug}
                  </div>
                </div>
                <span class={origination_badge_class(grant.origination_status)}>
                  {origination_label(grant.origination_status)}
                </span>
              </div>

              <dl class="grid grid-cols-1 gap-2 sm:grid-cols-2">
                <div class="min-w-0">
                  <dt class="text-xs uppercase tracking-wide text-base-content/60">
                    Data health
                  </dt>
                  <dd
                    data-role="client-data-health"
                    class="mt-1 text-sm text-base-content break-words"
                  >
                    {data_health_label(@stats, grant.client_account_id)}
                  </dd>
                </div>
                <div class="min-w-0">
                  <dt class="text-xs uppercase tracking-wide text-base-content/60">
                    Last activity
                  </dt>
                  <dd
                    data-role="client-last-activity"
                    class="mt-1 text-sm text-base-content break-words"
                  >
                    {last_activity_label(@stats, grant.client_account_id)}
                  </dd>
                </div>
              </dl>
            </button>
            <div class="flex items-center justify-between gap-2 border-t border-neutral px-4 py-2">
              <span class="text-xs text-base-content/60">
                {if grant.comped, do: "Comped — no subscription needed", else: "Billed normally"}
              </span>
              <button
                type="button"
                phx-click="toggle_comp"
                phx-value-account_id={grant.client_account_id}
                data-role="toggle-comp"
                class={["btn btn-xs", if(grant.comped, do: "btn-ghost", else: "btn-outline")]}
              >
                {if grant.comped, do: "Remove comp", else: "Comp"}
              </button>
            </div>
          </li>
        </ul>
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

    stats = load_client_stats(grants)

    socket =
      socket
      |> assign(:grants, grants)
      |> assign(:stats, stats)
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
        {:noreply,
         put_flash(socket, :error, "You are not authorized to generate a referral link")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to generate a referral link")}
    end
  end

  def handle_event("toggle_comp", %{"account_id" => id_str}, socket) do
    scope = socket.assigns.current_scope
    agency_id = socket.assigns[:active_account_id]
    client_account_id = String.to_integer(id_str)
    grant = Enum.find(socket.assigns.grants, &(&1.client_account_id == client_account_id))

    case grant && Agencies.set_client_comped(scope, agency_id, client_account_id, !grant.comped) do
      {:ok, updated} ->
        grants =
          Enum.map(socket.assigns.grants, fn
            %{id: id} = g when id == updated.id -> %{g | comped: updated.comped}
            g -> g
          end)

        {:noreply, assign(socket, :grants, grants)}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Only agency owners and admins can comp clients")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to update comp status")}
    end
  end

  def handle_event("open_client", %{"account_id" => id_str}, socket) do
    scope = socket.assigns.current_scope
    client_account_id = String.to_integer(id_str)
    Accounts.touch_membership(scope, client_account_id)
    {:noreply, push_navigate(socket, to: ~p"/app/dashboard")}
  end

  # ---------------------------------------------------------------------------
  # Data-source health and last activity
  # ---------------------------------------------------------------------------

  defp load_client_stats([]), do: %{}

  defp load_client_stats(grants) do
    account_ids = Enum.map(grants, & &1.client_account_id)

    rows =
      from(i in Integration,
        where: i.account_id in ^account_ids,
        select: {i.account_id, i.expires_at, i.updated_at}
      )
      |> Repo.all()

    now = DateTime.utc_now()

    Enum.reduce(rows, %{}, fn {account_id, expires_at, updated_at}, acc ->
      prev = Map.get(acc, account_id, %{total: 0, connected: 0, last_activity: nil})

      connected_inc =
        if expires_at && DateTime.compare(expires_at, now) == :gt, do: 1, else: 0

      Map.put(acc, account_id, %{
        total: prev.total + 1,
        connected: prev.connected + connected_inc,
        last_activity: latest(prev.last_activity, updated_at)
      })
    end)
  end

  defp latest(nil, b), do: b
  defp latest(a, nil), do: a
  defp latest(a, b), do: if(DateTime.compare(a, b) == :gt, do: a, else: b)

  defp data_health_label(stats, account_id) do
    case Map.get(stats, account_id) do
      %{total: total, connected: connected} when total > 0 and connected == total ->
        "All #{total} sources connected"

      %{total: total, connected: 0} when total > 0 ->
        "#{total} #{pluralize_source(total)} need reconnecting"

      %{total: total, connected: connected} when total > 0 ->
        "#{connected} of #{total} connected"

      _ ->
        "No data sources yet"
    end
  end

  defp pluralize_source(1), do: "source"
  defp pluralize_source(_), do: "sources"

  defp last_activity_label(stats, account_id) do
    case Map.get(stats, account_id) do
      %{last_activity: %DateTime{} = dt} -> format_relative(dt)
      _ -> "No activity yet"
    end
  end

  defp format_relative(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3_600 -> "#{div(diff, 60)} min ago"
      diff < 86_400 -> "#{div(diff, 3_600)} h ago"
      diff < 2 * 86_400 -> "yesterday"
      diff < 30 * 86_400 -> "#{div(diff, 86_400)} days ago"
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end

  defp origination_label(:originator), do: "Originated"
  defp origination_label(:invited), do: "Invited"
  defp origination_label(_), do: "Unknown"

  defp origination_badge_class(:originator), do: "badge badge-accent"
  defp origination_badge_class(_), do: "badge badge-ghost"
end
