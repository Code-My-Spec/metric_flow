defmodule MetricFlowWeb.IntegrationLive.Index do
  @moduledoc """
  The account's data sources, grouped by sign-in: Google (Analytics, Ads,
  Search Console, Business Profile, YouTube), Meta and QuickBooks.

  Each product shows its `MetricFlow.Onboarding` status, what it syncs, when
  it last synced, and one primary action — sync, choose what to sync, or
  reconnect. Connecting and picking happen in the setup wizard
  (`/app/onboarding/connect`); this page links into the wizard step that
  owns each connection. Manual sync, disconnect and live sync status stay
  here.
  """

  use MetricFlowWeb, :live_view

  import MetricFlowWeb.SetupComponents

  alias MetricFlow.Accounts
  alias MetricFlow.DataSync
  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Onboarding

  # Products, keyed by provider; `name` is used in sync flashes. Row copy
  # comes from `Onboarding.status/1`.
  @data_platforms [
    %{key: :youtube, provider: :youtube, name: "YouTube"},
    %{key: :google_analytics, provider: :google_analytics, name: "Google Analytics"},
    %{key: :google_ads, provider: :google_ads, name: "Google Ads"},
    %{
      key: :google_search_console,
      provider: :google_search_console,
      name: "Google Search Console"
    },
    %{key: :google_business, provider: :google_business, name: "Google Business"},
    %{key: :facebook_ads, provider: :facebook_ads, name: "Facebook Ads"},
    %{key: :quickbooks, provider: :quickbooks, name: "QuickBooks"}
  ]

  # Provider display names for flashes and the disconnect dialog.
  @provider_names %{
    youtube: "YouTube",
    google_analytics: "Google Analytics",
    google_ads: "Google Ads",
    google_search_console: "Google Search Console",
    google_business: "Google Business",
    facebook_ads: "Facebook",
    quickbooks: "QuickBooks"
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

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
      <div class="mx-auto max-w-4xl" data-role="integrations-index">
        <div class="mb-6 flex flex-wrap items-start justify-between gap-x-4 gap-y-3">
          <div class="min-w-0">
            <h1 class="text-2xl font-bold">Integrations</h1>
            <p class="mt-1 text-base-content/60">
              <%= if @nothing_connected do %>
                No platforms connected yet. Connect one to start seeing your metrics.
              <% else %>
                Where your metrics come from, and what each platform syncs.
              <% end %>
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <.link
              id="setup-data-sources"
              navigate={~p"/app/onboarding/connect"}
              class="btn btn-primary btn-sm"
            >
              Set up data sources
            </.link>
            <.link navigate={~p"/app/integrations/connect"} class="btn btn-ghost btn-sm">
              Connect a Platform
            </.link>
          </div>
        </div>

        <div class="space-y-6">
          <section
            :for={conn <- @groups}
            id={"connection-group-#{conn.key}"}
            data-state={conn.state}
            class="rounded-box border border-base-300 bg-base-100"
          >
            <header class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 px-4 py-3 sm:px-5">
              <div class="min-w-0">
                <h2 class="text-lg font-semibold">{conn.name}</h2>
                <p class="text-sm text-base-content/60">
                  {group_subtitle(conn)}
                </p>
              </div>
              <.link
                :if={conn.state == :not_connected}
                id={"group-action-#{conn.key}"}
                data-role="reconnect-integration"
                navigate={wizard_path(conn.key)}
                class="btn btn-primary btn-sm shrink-0"
              >
                {group_action_label(conn)}
              </.link>
            </header>

            <div
              :if={Enum.any?(conn.products, & &1.integration)}
              data-role="integrations-list"
              class="divide-y divide-base-300"
            >
              <.product_row
                :for={product <- conn.products}
                :if={product.integration}
                product={product}
                connection={conn.key}
                syncing={MapSet.member?(@syncing, product.key)}
                sync_result={Map.get(@sync_results, product.key)}
                last_synced_at={@last_synced_at[product.key]}
                next_sync_at={@next_sync_at}
                can_sync={@can_sync}
                can_modify={@can_modify}
                account_name={@active_account_name}
              />
            </div>

            <ul
              :if={Enum.any?(conn.products, &is_nil(&1.integration))}
              data-role="available-platforms-list"
              class={[
                "px-4 py-3 sm:px-5",
                Enum.any?(conn.products, & &1.integration) && "border-t border-base-300"
              ]}
            >
              <li
                :for={product <- conn.products}
                :if={is_nil(product.integration)}
                data-role="integration-card"
                data-platform={Atom.to_string(product.key)}
                data-status="available"
                class="flex flex-wrap items-center justify-between gap-2 py-1.5"
              >
                <div class="min-w-0">
                  <span data-role="integration-platform-name" class="font-medium">
                    {product.name}
                  </span>
                  <span class="text-sm text-base-content/60">— {product.gives}</span>
                </div>
                <div class="flex items-center gap-2">
                  <.status_badge status={product.status} data-role="integration-sync-status" />
                  <.link
                    :if={product.status == :not_granted}
                    data-role="reconnect-integration"
                    navigate={wizard_path(conn.key)}
                    class="btn btn-ghost btn-xs"
                  >
                    Grant access
                  </.link>
                </div>
              </li>
            </ul>
          </section>
        </div>

        <%= if @disconnecting do %>
          <% disc_provider_name = provider_display_name(@disconnecting) %>
          <dialog
            class="modal modal-open"
            data-role="disconnect-modal"
          >
            <div class="modal-box">
              <h3 class="font-bold text-lg">Disconnect {disc_provider_name}?</h3>
              <p class="py-4" data-role="disconnect-warning">
                Are you sure you want to disconnect <strong>{disc_provider_name}</strong>?
                This will affect all platforms that use this connection.
                Historical data will remain available, but no new data will sync after disconnecting.
              </p>
              <div class="modal-action">
                <button
                  data-role="cancel-disconnect"
                  phx-click="cancel_disconnect"
                  class="btn"
                >
                  Cancel
                </button>
                <button
                  data-role="confirm-disconnect"
                  phx-click="disconnect"
                  phx-value-provider={Atom.to_string(@disconnecting)}
                  class="btn btn-error"
                >
                  Disconnect
                </button>
              </div>
            </div>
            <form method="dialog" class="modal-backdrop">
              <button phx-click="cancel_disconnect">close</button>
            </form>
          </dialog>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :product, :map, required: true
  attr :connection, :atom, required: true
  attr :syncing, :boolean, default: false
  attr :sync_result, :map, default: nil
  attr :last_synced_at, :any, default: nil
  attr :next_sync_at, :any, default: nil
  attr :can_sync, :boolean, default: false
  attr :can_modify, :boolean, default: false
  attr :account_name, :string, default: nil

  defp product_row(assigns) do
    ~H"""
    <div
      data-role="integration-card"
      data-platform={Atom.to_string(@product.key)}
      data-status={if @product.status == :reconnect, do: "error", else: "connected"}
      class="px-4 py-4 sm:px-5"
    >
      <div data-role="integration-row" class="flex flex-wrap items-start justify-between gap-3">
        <div class="min-w-0 flex-1 basis-60">
          <div class="flex flex-wrap items-center gap-2">
            <h3 data-role="integration-platform-name" class="font-semibold">{@product.name}</h3>
            <.status_badge
              status={@product.status}
              data-status={if @product.status == :reconnect, do: "error", else: "connected"}
            />
          </div>

          <p data-role="integration-selected-accounts" class="mt-1 text-sm">
            <%= cond do %>
              <% @product.status == :reconnect -> %>
                <span class="text-error">
                  The sign-in expired — reconnect to resume syncing.
                </span>
              <% @product.key == :youtube -> %>
                <span class="text-base-content/60">
                  Owned by {@account_name} · {channel_count(@product.selected)}
                </span>
              <% @product.selected != [] -> %>
                <span class="text-base-content/60">Selected:</span>
                <span class="break-all">{Enum.join(@product.selected, ", ")}</span>
              <% true -> %>
                <span class="text-base-content/60">
                  Nothing selected yet — choose the {@product.noun} to sync.
                </span>
            <% end %>
          </p>

          <p class="mt-1 flex flex-wrap gap-x-2 text-xs text-base-content/60">
            <span data-role="last-sync-at">
              <%= if @last_synced_at do %>
                Last synced {format_datetime(@last_synced_at)}
              <% else %>
                Never synced
              <% end %>
            </span>
            <span
              :if={@product.key != :youtube and @product.status != :reconnect}
              data-role="next-sync-at"
            >
              · Next sync {format_datetime(@next_sync_at)}
            </span>
            <span data-role="integration-connected-date">
              · Connected {Calendar.strftime(@product.integration.inserted_at, "%b %d, %Y")}
            </span>
          </p>

          <div data-role="integration-sync-status" class="mt-2 flex items-center gap-1 empty:hidden">
            <span :if={@syncing} class="badge badge-warning badge-sm">
              Syncing <span class="loading loading-spinner loading-xs ml-1"></span>
            </span>
            <span :if={!@syncing && @sync_result} class="badge badge-success badge-sm">
              Synced {@sync_result.records_synced} records at {Calendar.strftime(
                @sync_result.completed_at,
                "%Y-%m-%d %H:%M"
              )} UTC
            </span>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-1">
          <%= case @product.status do %>
            <% :reconnect -> %>
              <.link
                :if={@can_modify}
                data-role="reconnect-integration"
                navigate={wizard_path(@connection)}
                class="btn btn-warning btn-sm"
              >
                Reconnect
              </.link>
            <% :needs_selection -> %>
              <.link
                :if={@can_modify}
                data-role="edit-integration-accounts"
                navigate={wizard_path(@connection)}
                class="btn btn-primary btn-sm"
              >
                Choose {@product.noun}
              </.link>
            <% _ready -> %>
              <button
                :if={@can_sync and @product.key != :youtube}
                phx-click="sync"
                phx-value-platform={Atom.to_string(@product.key)}
                phx-value-provider={Atom.to_string(@product.key)}
                phx-disable-with="Starting…"
                disabled={@syncing}
                class="btn btn-outline btn-sm"
              >
                Sync Now
              </button>
              <.link
                :if={@can_modify}
                data-role="edit-integration-accounts"
                navigate={wizard_path(@connection)}
                class="btn btn-ghost btn-sm"
              >
                Change
              </.link>
          <% end %>
          <.link
            data-role="integration-detail-link"
            navigate={~p"/app/integrations/connect/#{Atom.to_string(@product.key)}"}
            class="btn btn-ghost btn-sm"
          >
            Manage
          </.link>
          <button
            :if={@can_modify}
            data-role="disconnect-integration"
            phx-click="confirm_disconnect"
            phx-value-provider={Atom.to_string(@product.key)}
            class="btn btn-ghost btn-sm text-error"
            aria-label={"Disconnect #{@product.name}"}
          >
            Disconnect
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope =
      MetricFlow.Users.Scope.put_account_id(
        socket.assigns.current_scope,
        socket.assigns.active_account_id
      )

    socket = assign(socket, :current_scope, scope)
    integrations = load_integrations(scope)

    if Phoenix.LiveView.connected?(socket) do
      DataSync.subscribe_sync_events(scope)
    end

    current_user_role =
      if socket.assigns.active_account_id do
        Accounts.get_user_role(scope, scope.user.id, socket.assigns.active_account_id)
      end

    last_synced_at =
      Map.new(@data_platforms, fn platform ->
        last_sync =
          if platform.provider == :youtube,
            do: nil,
            else: DataSync.get_last_successful_sync_at(scope, platform.provider)

        {platform.provider, last_sync}
      end)

    socket =
      socket
      |> assign_integrations(integrations)
      |> assign(:syncing, MapSet.new())
      |> assign(:sync_results, %{})
      |> assign(:disconnecting, nil)
      |> assign(:can_sync, current_user_role in [:owner, :admin])
      |> assign(:can_modify, current_user_role in [:owner, :admin, :account_manager])
      |> assign(:last_synced_at, last_synced_at)
      |> assign(:next_sync_at, next_scheduled_sync_at())

    {:ok, socket}
  end

  # Groups come from `Onboarding.status/1`; a product whose token is still
  # expired after the refresh attempt in `load_integrations/1` needs a
  # reconnect even if it has a refresh token (the provider refused it).
  defp assign_integrations(socket, integrations) do
    by_provider = Map.new(integrations, &{&1.provider, &1})

    groups =
      socket.assigns.current_scope
      |> Onboarding.status()
      |> Enum.map(fn conn ->
        products =
          Enum.map(conn.products, fn product ->
            integration = Map.get(by_provider, product.key)

            status =
              if integration && needs_reconnect?(integration),
                do: :reconnect,
                else: product.status

            Map.merge(product, %{integration: integration, status: status})
          end)

        %{conn | products: products, state: group_state(products)}
      end)

    socket
    |> assign(:integrations, integrations)
    |> assign(:groups, groups)
    |> assign(:nothing_connected, Enum.all?(groups, &(&1.state == :not_connected)))
  end

  defp group_state(products) do
    statuses = Enum.map(products, & &1.status)

    cond do
      Enum.all?(statuses, &(&1 == :not_connected)) -> :not_connected
      :reconnect in statuses -> :reconnect
      :needs_selection in statuses -> :needs_selection
      true -> :done
    end
  end

  defp channel_count([_]), do: "1 channel connected"
  defp channel_count(ids), do: "#{length(ids)} channels connected"

  defp wizard_path(connection), do: ~p"/app/onboarding/connect?step=#{connection}"

  defp group_subtitle(%{state: :not_connected, description: description}), do: description

  defp group_subtitle(%{products: products}) do
    ready = Enum.count(products, &(&1.status == :ready))
    connected = Enum.count(products, & &1.integration)

    accounts =
      products |> Enum.map(& &1.connected_as) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    as = if accounts == [], do: "", else: " · signed in as #{Enum.join(accounts, ", ")}"
    "#{ready} of #{connected} ready#{as}"
  end

  defp group_action_label(%{key: :facebook_ads}), do: "Connect Facebook & Instagram"
  defp group_action_label(%{name: name}), do: "Connect #{name}"

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("sync", %{"provider" => "youtube"}, socket) do
    {:noreply,
     put_flash(socket, :info, "YouTube is connected. Analytics syncing is not available yet.")}
  end

  def handle_event("sync", %{"platform" => platform_str, "provider" => provider_str}, socket) do
    platform_key = String.to_existing_atom(platform_str)
    provider = String.to_existing_atom(provider_str)
    scope = socket.assigns.current_scope
    platform_name = find_platform_name(platform_key)

    cond do
      not socket.assigns.can_sync ->
        {:noreply, put_flash(socket, :error, "You are not authorized to trigger a sync.")}

      MapSet.member?(socket.assigns.syncing, platform_key) ->
        {:noreply,
         put_flash(socket, :error, "A sync for #{platform_name} is already in progress.")}

      true ->
        case DataSync.sync_integration(scope, provider) do
          {:ok, _sync_job} ->
            socket =
              socket
              |> assign(:syncing, MapSet.put(socket.assigns.syncing, platform_key))
              |> put_flash(:info, "Sync started for #{platform_name}")

            {:noreply, socket}

          {:error, :not_found} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "#{platform_name} integration not found. Please connect it first."
             )}

          {:error, :not_connected} ->
            {:noreply,
             put_flash(socket, :error, "#{platform_name} token has expired. Please reconnect.")}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, read_only_message())}

          {:error, reason} ->
            require Logger
            Logger.error("Sync failed for #{platform_name}: #{inspect(reason)}")

            {:noreply,
             put_flash(
               socket,
               :error,
               "Failed to start sync for #{platform_name}: #{inspect(reason)}"
             )}
        end
    end
  end

  # Fallback for legacy sync events that only pass provider
  def handle_event("sync", %{"provider" => provider_str}, socket) do
    provider = String.to_existing_atom(provider_str)
    scope = socket.assigns.current_scope
    platform_name = find_platform_name(provider)

    cond do
      not socket.assigns.can_sync ->
        {:noreply, put_flash(socket, :error, "You are not authorized to trigger a sync.")}

      MapSet.member?(socket.assigns.syncing, provider) ->
        {:noreply,
         put_flash(socket, :error, "A sync for #{platform_name} is already in progress.")}

      true ->
        case DataSync.sync_integration(scope, provider) do
          {:ok, _sync_job} ->
            socket =
              socket
              |> assign(:syncing, MapSet.put(socket.assigns.syncing, provider))
              |> put_flash(:info, "Sync started for #{platform_name}")

            {:noreply, socket}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, read_only_message())}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Integration not found.")}
        end
    end
  end

  @impl true
  def handle_event("confirm_disconnect", %{"provider" => provider_str}, socket) do
    provider = String.to_existing_atom(provider_str)
    {:noreply, assign(socket, :disconnecting, provider)}
  end

  @impl true
  def handle_event("cancel_disconnect", _params, socket) do
    {:noreply, assign(socket, :disconnecting, nil)}
  end

  @impl true
  def handle_event("disconnect", %{"provider" => provider_str}, socket) do
    provider = String.to_existing_atom(provider_str)
    scope = socket.assigns.current_scope

    if socket.assigns.can_modify do
      case disconnect_provider(scope, provider) do
        {:ok, _} ->
          socket =
            socket
            |> assign_integrations(Integrations.list_integrations(scope))
            |> assign(:disconnecting, nil)
            |> put_flash(
              :info,
              "Disconnected from #{provider_display_name(provider)}. " <>
                "Historical data is retained; no new data will sync after disconnecting."
            )

          {:noreply, socket}

        {:error, _} ->
          socket =
            socket
            |> assign(:disconnecting, nil)
            |> put_flash(:error, "Failed to disconnect integration.")

          {:noreply, socket}
      end
    else
      {:noreply,
       socket
       |> assign(:disconnecting, nil)
       |> put_flash(:error, "You are not authorized to disconnect integrations.")}
    end
  end

  # ---------------------------------------------------------------------------
  # Message handlers (async sync completion)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(
        {:sync_completed,
         %{provider: provider, records_synced: count, completed_at: completed_at}},
        socket
      ) do
    result = %{records_synced: count, completed_at: completed_at}

    # Store result under each platform key that maps to this provider,
    # since the template looks up by platform key (e.g. :google_analytics),
    # not by OAuth provider (e.g. :google).
    platform_keys = platform_keys_for_provider(provider)

    sync_results =
      Enum.reduce(platform_keys, socket.assigns.sync_results, fn key, acc ->
        Map.put(acc, key, result)
      end)

    syncing =
      socket.assigns.syncing
      |> MapSet.delete(provider)
      |> remove_platform_keys_for_provider(provider)

    socket =
      socket
      |> assign(:syncing, syncing)
      |> assign(:sync_results, sync_results)

    {:noreply, socket}
  end

  def handle_info(
        {:sync_failed, %{provider: provider, reason: reason}},
        socket
      ) do
    syncing =
      socket.assigns.syncing
      |> MapSet.delete(provider)
      |> remove_platform_keys_for_provider(provider)

    socket =
      socket
      |> assign(:syncing, syncing)
      |> put_flash(:error, build_failure_message(provider, reason))

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_failure_message(provider, reason) when is_binary(reason) and reason != "" do
    "Sync failed for #{provider_display_name(provider)}: #{reason}"
  end

  defp build_failure_message(provider, _reason) do
    "Sync failed for #{provider_display_name(provider)}. Please check your connection and try again."
  end

  defp platform_keys_for_provider(provider) do
    @data_platforms
    |> Enum.filter(&(&1.provider == provider))
    |> Enum.map(& &1.key)
  end

  defp remove_platform_keys_for_provider(syncing, provider) do
    @data_platforms
    |> Enum.filter(&(&1.provider == provider))
    |> Enum.reduce(syncing, fn p, acc -> MapSet.delete(acc, p.key) end)
  end

  # Emails the account's owners and admins once when an integration's credentials expire, and clears
  # the flag once it's reconnected (expires_at pushed back out) so a future
  # expiration notifies again rather than staying silent forever.
  defp notify_expired_integrations(integrations) do
    Enum.map(integrations, fn integration ->
      cond do
        not Map.has_key?(@provider_names, integration.provider) ->
          integration

        needs_reconnect?(integration) and is_nil(integration.reconnection_notified_at) ->
          integration
          |> Integrations.notify_reconnection_required(
            provider_display_name(integration.provider)
          )
          |> updated_or(integration)

        not needs_reconnect?(integration) and
            not is_nil(integration.reconnection_notified_at) ->
          integration
          |> Integrations.put_reconnection_notified_at(nil)
          |> updated_or(integration)

        true ->
          integration
      end
    end)
  end

  defp read_only_message,
    do: "Only account owners, admins and account managers can sync or change integrations."

  defp updated_or({:ok, updated}, _integration), do: updated
  defp updated_or(_error, integration), do: integration

  defp find_platform_name(platform_key) do
    case Enum.find(@data_platforms, fn p -> p.key == platform_key end) do
      nil -> platform_key |> Atom.to_string() |> derive_display_name()
      platform -> platform.name
    end
  end

  defp provider_display_name(provider_key) do
    Map.get(
      @provider_names,
      provider_key,
      provider_key |> Atom.to_string() |> derive_display_name()
    )
  end

  defp derive_display_name(provider_str) do
    provider_str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  # Looks up the selected account value from provider_metadata using the correct key per provider.

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %H:%M UTC")
  end

  defp format_datetime(_), do: ""

  # Google products share one OAuth grant; `Onboarding.disconnect/2` avoids
  # revoking the token while sibling Google products still use it.
  defp disconnect_provider(scope, provider) do
    if provider in Onboarding.product_keys() do
      case Onboarding.disconnect(scope, provider) do
        :ok -> {:ok, provider}
        other -> other
      end
    else
      Integrations.disconnect(scope, provider)
    end
  end

  # Access tokens for Google and QuickBooks expire hourly and normally
  # refresh silently, so an expired access token alone isn't a problem. Try
  # the refresh first; only a token that is still expired afterwards (no
  # refresh token, or the provider refused it) needs the user to reconnect.
  defp load_integrations(scope) do
    scope
    |> Integrations.list_integrations()
    |> Enum.map(&refresh_if_expired(scope, &1))
    |> notify_expired_integrations()
  end

  defp refresh_if_expired(scope, integration) do
    if Integration.expired?(integration) and Integration.has_refresh_token?(integration) do
      case Integrations.ensure_fresh_token(scope, integration) do
        {:ok, refreshed} -> refreshed
        {:error, _} -> integration
      end
    else
      integration
    end
  end

  defp needs_reconnect?(integration), do: Integration.expired?(integration)

  defp next_scheduled_sync_at do
    now = DateTime.utc_now()
    today_run = %{now | hour: 2, minute: 0, second: 0, microsecond: {0, 0}}

    if DateTime.compare(now, today_run) == :lt do
      today_run
    else
      DateTime.add(today_run, 1, :day)
    end
  end
end
