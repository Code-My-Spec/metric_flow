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
      active_account_type={assigns[:active_account_type]}
    >
      <div class="mx-auto max-w-3xl space-y-6 overflow-x-hidden">
        <header class="space-y-1">
          <h1 class="text-2xl font-semibold text-base-content break-words">Your Accounts</h1>
          <p class="text-sm text-base-content/70 break-words">
            Pick an account to work in. The active one drives every other page.
          </p>
        </header>

        <section id="accounts" class="space-y-4">
          <div
            :if={@accounts == []}
            class="rounded-box border border-neutral bg-base-200 p-6 text-center space-y-2"
          >
            <h2 class="text-lg font-semibold text-base-content">No accounts found.</h2>
            <p class="text-sm text-base-content/70">
              You aren't a member of any account yet. Create a team below to get started.
            </p>
          </div>

          <article
            :for={account <- @accounts}
            data-role="account-card"
            data-account-id={account.id}
            data-active={to_string(account.id == @active_account_id)}
            class={[
              "rounded-box border bg-base-200 p-4 sm:p-6 space-y-4",
              if(account.id == @active_account_id,
                do: "border-primary",
                else: "border-neutral"
              )
            ]}
          >
            <div class="min-w-0 space-y-2">
              <h2 class="text-lg font-semibold text-base-content break-words">
                {account.name}
              </h2>
              <dl class="flex flex-wrap gap-2 text-xs">
                <div class="flex items-center gap-1">
                  <dt class="sr-only">Type</dt>
                  <dd class={account_type_badge_class(account)}>
                    {account_type_label(account)}
                  </dd>
                </div>
                <div class="flex items-center gap-1">
                  <dt class="text-base-content/60">Role</dt>
                  <dd class="rounded-box border border-neutral bg-base-100 px-2 py-0.5 font-semibold text-base-content/80">
                    {to_string(Map.get(@account_roles, account.id, :member))}
                  </dd>
                </div>
                <%= if grant = Map.get(@agency_grants, account.id) do %>
                  <div class="flex items-center gap-1">
                    <dt class="text-base-content/60">Access</dt>
                    <dd class="rounded-box border border-accent bg-base-100 px-2 py-0.5 font-semibold text-accent">
                      {access_level_label(grant.access_level)}
                    </dd>
                  </div>
                  <div class="flex items-center gap-1">
                    <dt class="sr-only">Origination</dt>
                    <dd class="rounded-box border border-neutral bg-base-100 px-2 py-0.5 text-base-content/70">
                      {origination_status_label(grant.origination_status)}
                    </dd>
                  </div>
                <% end %>
              </dl>
            </div>

            <button
              data-role="switch-account"
              phx-click="switch_account"
              phx-value-account_id={account.id}
              disabled={account.id == @active_account_id}
              class={
                if account.id == @active_account_id,
                  do:
                    "w-full rounded-box border border-primary bg-base-100 px-4 py-2 text-sm font-semibold text-primary cursor-default sm:w-auto",
                  else:
                    "btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
              }
            >
              {if account.id == @active_account_id,
                do: "#{account.name} Active",
                else: "Switch to #{account.name}"}
            </button>
          </article>
        </section>

        <section
          aria-labelledby="create-team-heading"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <header class="space-y-1">
            <h2 id="create-team-heading" class="text-lg font-semibold text-base-content">
              Create Team Account
            </h2>
            <p class="text-sm text-base-content/70">
              Spin up a new team workspace. You'll be its owner.
            </p>
          </header>
          <.form
            for={@team_form}
            id="team_form"
            phx-submit="create_team"
            phx-change="validate_team"
            class="mt-4 space-y-4"
          >
            <.input field={@team_form[:name]} label="Name" placeholder="My Team" />
            <div class="space-y-1">
              <.input
                field={@team_form[:slug]}
                label="Slug"
                class="input input-bordered w-full font-mono bg-base-100 border-neutral rounded-box"
                placeholder="my-team"
              />
              <p class="text-xs text-base-content/60 break-words">
                Lowercase letters, numbers, and hyphens.
              </p>
            </div>
            <button
              type="submit"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
            >
              Create Team
            </button>
          </.form>
        </section>
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

    # Prefer the account the user most recently explicitly switched to
    # (touch_membership/2) -- this is what keeps this page's "Active" account
    # in sync with the switch a user just made, which primary_account/2 alone
    # couldn't do (it always preferred the user's own account, ignoring any
    # switch). Only when nothing has ever been explicitly switched to --
    # e.g. right after being granted access to a new account, before ever
    # using the switcher -- fall back to the user's own account, rather than
    # whichever membership happens to be newest in the database.
    switched_account_id = Accounts.most_recently_switched_account_id(scope)

    primary =
      case switched_account_id && Enum.find(accounts, &(&1.id == switched_account_id)) do
        nil -> ActiveAccountHook.primary_account(accounts, scope.user)
        account -> account
      end

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

  defp account_type_badge_class(%Account{type: :agency}),
    do: "rounded-box border border-secondary bg-base-100 px-2 py-0.5 font-semibold text-secondary"

  defp account_type_badge_class(%Account{}),
    do: "rounded-box border border-primary bg-base-100 px-2 py-0.5 font-semibold text-primary"

  defp account_type_label(%Account{type: :client}), do: "Client"
  defp account_type_label(%Account{type: :agency}), do: "Agency"

  defp access_level_label(:read_only), do: "Read Only"
  defp access_level_label(:account_manager), do: "Account Manager"
  defp access_level_label(:admin), do: "Admin"
  defp access_level_label(other), do: to_string(other)

  defp origination_status_label(:originator), do: "Originator"
  defp origination_status_label(:invited), do: "Invited"
  defp origination_status_label(other), do: to_string(other)
end
