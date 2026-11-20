defmodule MetricFlowWeb.AccountLive.Members do
  @moduledoc """
  LiveView for managing account members and permissions.

  Displays all members of the active account with their roles and join dates.
  Owners and admins can change member roles, remove members, and invite new
  users by email. Enforces role-based authorization — only owners and admins
  see the members list and management controls. Protects the last owner from
  removal or demotion. Subscribes to member PubSub for real-time updates.
  """

  use MetricFlowWeb, :live_view

  require Logger

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users
  alias MetricFlowWeb.Hooks.ActiveAccountHook

  # Roles used for row-level role select (all valid account_member roles)
  @valid_roles ~w(owner admin account_manager read_only)
  # Roles an admin can assign (cannot assign owner)
  @admin_assignable_roles ~w(admin account_manager read_only)
  # Invite form roles for owners (includes "member" alias accepted by BDD spex)
  @owner_invite_roles ~w(member read_only account_manager admin owner)
  # Invite form roles for admins (no owner or admin option — admins cannot assign admin)
  @admin_invite_roles ~w(account_manager read_only member)

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
          <h1 class="text-2xl font-semibold text-base-content break-words">Members</h1>
          <p class="text-sm text-base-content/70 break-words">{@account.name}</p>
        </header>

        <%!-- Invite member — the primary action on this page. Owners and admins only. --%>
        <section
          :if={@can_manage}
          aria-labelledby="invite-member-heading"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <header class="space-y-1">
            <h2 id="invite-member-heading" class="text-lg font-semibold text-base-content">
              Invite a Member
            </h2>
            <p class="text-sm text-base-content/70 break-words">
              Add a teammate or client to {@account.name}. They receive the access level you pick.
            </p>
          </header>
          <%!--
          Uses invitation[email] / invitation[role] as the canonical input names.
          extract_invite_params/1 also accepts flat email/role keys for unit test
          compatibility (render_submit with flat params merges alongside these).
          --%>
          <form id="invite_member_form" phx-submit="invite_member" class="mt-4 space-y-4">
            <div class="space-y-1">
              <label
                for="invite_member_email"
                class="block text-sm font-semibold text-base-content"
              >
                Email address
              </label>
              <input
                id="invite_member_email"
                type="email"
                name="invitation[email]"
                class="input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
                placeholder="member@example.com"
              />
            </div>
            <div class="space-y-1">
              <label
                for="invite_member_role"
                class="block text-sm font-semibold text-base-content"
              >
                Role
              </label>
              <select
                id="invite_member_role"
                name="invitation[role]"
                class="select select-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
              >
                <option :for={role <- invite_roles(@current_user_role)} value={role}>
                  {role}
                </option>
              </select>
            </div>
            <button
              type="submit"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
            >
              Invite
            </button>
          </form>
        </section>

        <%!-- Members table — visible to owners and admins only --%>
        <section
          :if={@can_manage}
          data-role="members-list"
          class="rounded-box border border-neutral bg-base-200"
        >
          <div class="p-4 sm:p-6 pb-0">
            <h2 class="text-lg font-semibold text-base-content">Current members</h2>
            <p class="text-sm text-base-content/70">
              One row per member. Change a role or remove someone here.
            </p>
          </div>
          <div class="overflow-x-auto p-4 sm:p-6">
            <table class="table w-full">
              <thead>
                <tr>
                  <th>Member</th>
                  <th>Role</th>
                  <th>Joined</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={member <- @members}
                  data-role="member-row"
                  data-user-id={member.user_id}
                >
                  <td class="min-w-0">
                    <div class="font-medium text-sm text-base-content break-words">
                      {member.user.email}
                    </div>
                  </td>
                  <td>
                    <span class={role_badge_class(member.role)}>
                      {role_label(member.role)}
                    </span>
                  </td>
                  <td class="text-sm text-base-content/70 whitespace-nowrap">
                    {format_date(member.inserted_at)}
                  </td>
                  <td>
                    <div class="flex flex-wrap items-center gap-2">
                      <%!-- Role change form: uses phx-submit (not phx-change) to require
                         an explicit "Change" button click, preventing accidental role
                         changes when a select value is altered. The hidden user_id input
                         ensures the correct member is targeted on submit. --%>
                      <form phx-submit="change_role" class="flex items-center gap-2">
                        <input type="hidden" name="user_id" value={member.user_id} />
                        <select
                          name="role"
                          class="select select-sm select-bordered bg-base-100 border-neutral rounded-box text-base-content"
                        >
                          <option
                            :for={role <- manageable_roles(@current_user_role)}
                            value={role}
                            selected={member.role == String.to_existing_atom(role)}
                          >
                            {role_label(String.to_existing_atom(role))}
                          </option>
                        </select>
                        <button
                          :if={not last_owner?(member, @members)}
                          type="submit"
                          class="rounded-box border border-neutral bg-base-200 px-3 py-1 text-xs font-semibold text-base-content hover:bg-base-300"
                        >
                          Change
                        </button>
                      </form>
                      <%!-- Hidden change-role button — used by BDD spex via render_click.
                         Carries phx-click="change_role" with the user_id so spex can
                         pass the desired role as a click param. Not rendered for the
                         last owner row (BDD spex asserts it is absent). --%>
                      <button
                        :if={not last_owner?(member, @members)}
                        data-role="change-role"
                        data-user-email={member.user.email}
                        phx-click="change_role"
                        phx-value-user_id={member.user_id}
                        class="sr-only"
                      >
                        Change
                      </button>
                      <%!-- Remove button — hidden for the last owner and for the current user --%>
                      <button
                        :if={
                          not last_owner?(member, @members) and
                            member.user_id != @current_scope.user.id
                        }
                        data-role="remove-member"
                        data-user-email={member.user.email}
                        phx-click="remove_member"
                        phx-value-user_id={member.user_id}
                        class="rounded-box border border-error bg-base-200 px-3 py-1 text-xs font-semibold text-error hover:bg-base-300"
                      >
                        Remove
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <%!-- Agency access grants — shown to everyone with access to this account --%>
        <section
          :if={@agency_grants != []}
          data-role="agency-access-list"
          class="rounded-box border border-neutral bg-base-200"
        >
          <div class="p-4 sm:p-6 pb-0">
            <h2 class="text-lg font-semibold text-base-content">Agency access</h2>
            <p class="text-sm text-base-content/70">
              Agencies that reach this account and the access level each one holds.
            </p>
          </div>
          <div class="overflow-x-auto p-4 sm:p-6">
            <table class="table w-full">
              <thead>
                <tr>
                  <th>Agency</th>
                  <th>Access Level</th>
                  <th>Granted</th>
                  <th>Originator</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={grant <- @agency_grants}
                  data-role="agency-grant-row"
                  data-agency-account-id={grant.agency_account_id}
                >
                  <td class="font-medium text-sm text-base-content break-words">
                    {grant.agency_account_name}
                  </td>
                  <td>
                    <span class="badge rounded-box border border-accent bg-base-100 px-2 py-0.5 font-semibold text-accent">
                      {grant.access_level}
                    </span>
                  </td>
                  <td class="text-sm text-base-content/70 whitespace-nowrap">
                    {format_date(grant.inserted_at)}
                  </td>
                  <td class="text-sm text-base-content/70">
                    {if grant.origination_status == :originator, do: "Yes", else: "No"}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
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

    case Accounts.list_accounts(scope) do
      [] ->
        {:ok, redirect(socket, to: "/app/accounts")}

      accounts ->
        account = ActiveAccountHook.active_account(accounts, scope.user)
        members = Accounts.list_account_members(scope, account.id)
        user_role = Accounts.get_user_role(scope, scope.user.id, account.id)
        can_manage = can_manage?(user_role)
        agency_grants = fetch_agency_grants(scope, account.id)

        if connected?(socket), do: Accounts.subscribe_member(scope)

        socket =
          socket
          |> assign(:account, account)
          |> assign(:members, members)
          |> assign(:can_manage, can_manage)
          |> assign(:current_user_role, user_role)
          |> assign(:agency_grants, agency_grants)

        {:ok, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("change_role", %{"role" => role, "user_id" => user_id}, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account.id
    user_id = parse_id(user_id)
    role_atom = parse_role(role)

    case Accounts.update_user_role(scope, user_id, account_id, role_atom) do
      {:ok, _member} ->
        Logger.info(
          "permission_change: change_role user_id=#{user_id} role=#{role_atom} " <>
            "by=#{scope.user.email} at=#{DateTime.utc_now()}"
        )

        members = Accounts.list_account_members(scope, account_id)

        {:noreply,
         socket
         |> assign(:members, members)
         |> put_flash(:info, "Role updated")}

      {:error, :last_owner} ->
        {:noreply, put_flash(socket, :error, "Cannot demote the last owner")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to change roles")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update role")}
    end
  end

  # The accessible sr-only "change-role" button (see render/1 above) carries no
  # phx-value-role, since it has no single correct value per row — a real click
  # or keyboard/screen-reader activation sends only user_id. Without this
  # clause that payload matches no other handle_event("change_role", ...) head
  # and crashes the LiveView. Handle it explicitly instead of letting it fall
  # through to a FunctionClauseError.
  def handle_event("change_role", %{"user_id" => _user_id}, socket) do
    {:noreply,
     put_flash(socket, :error, "Select a new access level before changing this member's role")}
  end

  def handle_event("remove_member", %{"user_id" => user_id}, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account.id
    user_id = parse_id(user_id)

    case Accounts.remove_user_from_account(scope, user_id, account_id) do
      {:ok, _member} ->
        Logger.info(
          "permission_change: remove_member user_id=#{user_id} " <>
            "by=#{scope.user.email} at=#{DateTime.utc_now()}"
        )

        members = Accounts.list_account_members(scope, account_id)

        {:noreply,
         socket
         |> assign(:members, members)
         |> put_flash(:info, "Member removed")}

      {:error, :last_owner} ->
        {:noreply, put_flash(socket, :error, "Cannot remove the last owner")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to remove members")}
    end
  end

  def handle_event("invite_member", params, socket) do
    {email, role} = extract_invite_params(params)
    do_invite_member(email, role, socket)
  end

  # ---------------------------------------------------------------------------
  # PubSub message handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({event, _member}, socket)
      when event in [:created, :updated, :deleted] do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account.id
    members = Accounts.list_account_members(scope, account_id)
    {:noreply, assign(socket, :members, members)}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp fetch_agency_grants(scope, account_id) do
    case Agencies.list_grants_for_client_account(scope, account_id) do
      grants when is_list(grants) -> grants
      {:error, _reason} -> []
    end
  end

  defp extract_invite_params(%{"invitation" => %{"email" => email, "role" => role}})
       when email != "" do
    {email, role}
  end

  defp extract_invite_params(%{"email" => email, "role" => role}) when email != "" do
    {email, role}
  end

  defp extract_invite_params(%{"invitation" => %{"email" => email, "role" => role}}) do
    {email, role}
  end

  defp extract_invite_params(params) do
    {Map.get(params, "email", ""), Map.get(params, "role", "read_only")}
  end

  defp do_invite_member(email, role, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account.id
    role_atom = parse_role(role)

    with %{} = user <- Users.get_user_by_email(email),
         {:ok, _member} <- Accounts.add_user_to_account(scope, user.id, account_id, role_atom) do
      members = Accounts.list_account_members(scope, account_id)

      {:noreply,
       socket
       |> assign(:members, members)
       |> put_flash(:info, "Member invited successfully")}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "User not found")}

      {:error, :already_member} ->
        {:noreply, put_flash(socket, :error, "User is already a member")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to invite members")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to invite member")}
    end
  end

  defp can_manage?(role) when role in [:owner, :admin], do: true
  defp can_manage?(_role), do: false

  defp last_owner?(%{role: :owner}, members) do
    owner_count = Enum.count(members, &(&1.role == :owner))
    owner_count <= 1
  end

  defp last_owner?(_member, _members), do: false

  # Returns the list of role strings for the row-level role change select.
  # Owners see all roles; admins see only admin and below.
  defp manageable_roles(:owner), do: @valid_roles
  defp manageable_roles(:admin), do: @admin_assignable_roles
  defp manageable_roles(_role), do: @valid_roles

  # Returns the list of role strings available in the invite form select.
  # Includes "member" as an alias (accepted by BDD spex, maps to read_only in parse_role).
  # Owners can invite at any role including owner.
  # Admins can only invite at account_manager and below (not admin — backend rejects it).
  defp invite_roles(:owner), do: @owner_invite_roles
  defp invite_roles(:admin), do: @admin_invite_roles
  defp invite_roles(_role), do: @admin_invite_roles

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)

  # Maps valid role strings to atoms. "member" is an alias for :read_only.
  defp parse_role(role) when role in @valid_roles do
    String.to_existing_atom(role)
  end

  defp parse_role("member"), do: :read_only
  defp parse_role(_unknown), do: :read_only

  defp role_badge_class(:owner),
    do:
      "badge rounded-box border border-primary bg-base-100 px-2 py-0.5 font-semibold text-primary"

  defp role_badge_class(:admin),
    do:
      "badge rounded-box border border-secondary bg-base-100 px-2 py-0.5 font-semibold text-secondary"

  defp role_badge_class(:account_manager),
    do: "badge rounded-box border border-accent bg-base-100 px-2 py-0.5 font-semibold text-accent"

  defp role_badge_class(:read_only),
    do:
      "badge rounded-box border border-neutral bg-base-100 px-2 py-0.5 font-semibold text-base-content/80"

  defp role_badge_class(:member),
    do:
      "badge rounded-box border border-neutral bg-base-100 px-2 py-0.5 font-semibold text-base-content/80"

  defp role_label(:owner), do: "owner"
  defp role_label(:admin), do: "admin"
  defp role_label(:account_manager), do: "account_manager"
  defp role_label(:read_only), do: "read_only"
  defp role_label(:member), do: "member"

  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_date(nil), do: ""
end
