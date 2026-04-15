defmodule MetricFlowWeb.AccountLive.Index do
  @moduledoc """
  LiveView for listing accounts the current user belongs to.

  Displays all personal and team accounts for the authenticated user, showing
  the user's membership role in each account and any agency access level and
  origination status for client accounts accessed via an agency grant. Allows
  the user to switch their active account context. Includes an inline form for
  creating new team accounts. Subscribes to account PubSub for real-time updates.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Agencies
  alias MetricFlowWeb.Hooks.ActiveAccountHook

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
    >
    <div class="mx-auto">
      <.header>Your Accounts</.header>

      <div class="mt-8 space-y-4">
        <div :if={@accounts == []} class="text-base-content/60 text-sm">
          No accounts found.
        </div>
        <div
          :for={account <- @accounts}
          data-role="account-card"
          data-account-id={account.id}
          data-active={to_string(account.id == @active_account_id)}
          class="card bg-base-200 p-6"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <h3 class="text-lg font-semibold">{account.name}</h3>
              <div class="mt-2 flex flex-wrap gap-2">
                <span class={account_type_badge_class(account)}>
                  {account_type_label(account)}
                </span>
                <span class="badge badge-ghost">
                  {to_string(Map.get(@account_roles, account.id, :member))}
                </span>
                <%= if grant = Map.get(@agency_grants, account.id) do %>
                  <span class="badge badge-accent">
                    {access_level_label(grant.access_level)}
                  </span>
                  <span class="badge badge-info">
                    {origination_status_label(grant.origination_status)}
                  </span>
                <% end %>
              </div>
            </div>
            <div class="ml-4 flex-shrink-0">
              <button
                data-role="switch-account"
                phx-click="switch_account"
                phx-value-account_id={account.id}
                disabled={account.id == @active_account_id}
                class={if account.id == @active_account_id, do: "btn btn-sm btn-ghost", else: "btn btn-sm btn-primary"}
              >
                {if account.id == @active_account_id, do: "#{account.name} (Active)", else: "Switch to #{account.name}"}
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <h2 class="text-base font-semibold mb-4">Create Team Account</h2>
        <.form
          for={@team_form}
          phx-submit="create_team"
          phx-change="validate_team"
          class="space-y-4"
        >
          <div class="form-control">
            <label class="label">
              <span class="label-text">Name</span>
            </label>
            <.input
              field={@team_form[:name]}
              class="input input-bordered w-full"
              placeholder="My Team"
            />
          </div>
          <div class="form-control">
            <label class="label">
              <span class="label-text">Slug</span>
            </label>
            <.input
              field={@team_form[:slug]}
              class="input input-bordered w-full font-mono"
              placeholder="my-team"
            />
            <label class="label">
              <span class="label-text-alt text-base-content/60">
                Lowercase letters, numbers, and hyphens
              </span>
            </label>
          </div>
          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary">Create Team</button>
          </div>
        </.form>
      </div>
    </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    accounts = Accounts.list_accounts(scope)

    if connected?(socket), do: Accounts.subscribe_account(scope)

    # Default to the user's own account, falling back to the most recent.
    primary = ActiveAccountHook.primary_account(accounts, scope.user)
    active_account_id = if primary, do: primary.id

    {account_roles, agency_grants} = load_account_metadata(scope, accounts)

    active_account_name = active_account_name(accounts, active_account_id)

    team_form = build_team_form(scope)

    socket =
      socket
      |> assign(:accounts, accounts)
      |> assign(:active_account_id, active_account_id)
      |> assign(:active_account_name, active_account_name)
      |> assign(:account_roles, account_roles)
      |> assign(:agency_grants, agency_grants)
      |> assign(:team_form, team_form)

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("switch_account", %{"account_id" => account_id_str}, socket) do
    scope = socket.assigns.current_scope
    account_id = String.to_integer(account_id_str)
    accounts = socket.assigns.accounts

    case Enum.find(accounts, fn a -> a.id == account_id end) do
      nil ->
        {:noreply, put_flash(socket, :error, "Account not found")}

      account ->
        active_account_name = active_account_name(accounts, account_id)

        socket =
          socket
          |> assign(:active_account_id, account_id)
          |> assign(:active_account_name, active_account_name)
          |> put_flash(:info, "Switched to #{account.name}")

        Accounts.touch_membership(scope, account_id)
        {:noreply, socket}
    end
  end

  def handle_event("create_team", %{"team" => team_params}, socket) do
    scope = socket.assigns.current_scope

    case Accounts.create_team_account(scope, team_params) do
      {:ok, _account} ->
        accounts = Accounts.list_accounts(scope)
        account_ids = Enum.map(accounts, & &1.id)
        active_account_id = socket.assigns.active_account_id || List.last(account_ids)
        {account_roles, agency_grants} = load_account_metadata(scope, accounts)
        active_account_name = active_account_name(accounts, active_account_id)

        socket =
          socket
          |> assign(:accounts, accounts)
          |> assign(:active_account_id, active_account_id)
          |> assign(:active_account_name, active_account_name)
          |> assign(:account_roles, account_roles)
          |> assign(:agency_grants, agency_grants)
          |> assign(:team_form, build_team_form(scope))
          |> put_flash(:info, "Team account created")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :team_form, to_form(changeset, as: "team", action: :insert))}
    end
  end

  def handle_event("validate_team", %{"team" => team_params}, socket) do
    scope = socket.assigns.current_scope
    changeset = Accounts.change_account(scope, %Account{}, team_params)
    {:noreply, assign(socket, :team_form, to_form(changeset, as: "team", action: :validate))}
  end

  # ---------------------------------------------------------------------------
  # PubSub message handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({event, _account}, socket)
      when event in [:created, :updated, :deleted] do
    scope = socket.assigns.current_scope
    accounts = Accounts.list_accounts(scope)
    active_account_id = socket.assigns.active_account_id
    {account_roles, agency_grants} = load_account_metadata(scope, accounts)
    active_account_name = active_account_name(accounts, active_account_id)

    socket =
      socket
      |> assign(:accounts, accounts)
      |> assign(:active_account_name, active_account_name)
      |> assign(:account_roles, account_roles)
      |> assign(:agency_grants, agency_grants)

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_team_form(scope) do
    changeset = Accounts.change_account(scope, %Account{})
    to_form(changeset, as: "team")
  end

  defp load_account_metadata(scope, accounts) do
    account_ids = Enum.map(accounts, & &1.id)

    account_roles =
      Map.new(accounts, fn account ->
        role = Accounts.get_user_role(scope, scope.user.id, account.id)
        {account.id, role}
      end)

    agency_grants =
      Map.new(accounts, fn account ->
        grant = Agencies.find_agency_grant_for_account(scope, account.id, account_ids)
        {account.id, grant}
      end)

    {account_roles, agency_grants}
  end

  defp active_account_name(accounts, active_account_id) do
    case Enum.find(accounts, fn a -> a.id == active_account_id end) do
      nil -> nil
      account -> account.name
    end
  end

  defp account_type_badge_class(%Account{type: "personal"}), do: "badge badge-primary"
  defp account_type_badge_class(%Account{}), do: "badge badge-ghost"

  defp account_type_label(%Account{type: "personal"}), do: "Personal"
  defp account_type_label(%Account{}), do: "Team"

  defp access_level_label(:read_only), do: "Read Only"
  defp access_level_label(:account_manager), do: "Account Manager"
  defp access_level_label(:admin), do: "Admin"
  defp access_level_label(other), do: to_string(other)

  defp origination_status_label(:originator), do: "Originator"
  defp origination_status_label(:invited), do: "Invited"
  defp origination_status_label(other), do: to_string(other)
end
