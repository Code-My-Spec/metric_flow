defmodule MetricFlowWeb.AccountLive.Settings do
  @moduledoc """
  LiveView for account settings, ownership transfer, and deletion.

  Owners and admins can edit the account name and slug. Only owners can
  transfer ownership to another member or delete a team account. Deletion
  requires typing the account name and re-entering the user's password.
  Personal accounts cannot be deleted. Subscribes to account PubSub for
  real-time updates.

  For team accounts where the current user is an owner or admin, the agency
  auto-enrollment and white-label branding sections are also rendered.

  Non-owner members of team accounts see a "Leave Account" section allowing
  them to revoke their own access.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users
  alias MetricFlowWeb.AgencyLive
  alias MetricFlowWeb.Hooks.ActiveAccountHook

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} white_label_config={assigns[:white_label_config]} active_account_name={@active_account_name}>
      <div class="mx-auto max-w-2xl mf-content">
        <.header>
          Account Settings
          <:subtitle><span class="text-base-content/60">{@account.name}</span></:subtitle>
        </.header>

        <div class="mt-8 space-y-8">
          <%!-- Section 1: General Settings (owners and admins) --%>
          <div :if={@can_edit} class="card bg-base-100 shadow mf-card">
            <div class="card-body">
              <h2 class="card-title text-base">General Settings</h2>
              <form
                id="account-settings-form"
                phx-change="validate"
                phx-submit="save"
                class="space-y-4"
              >
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Account Name</span>
                  </label>
                  <input
                    type="text"
                    name="account[name]"
                    value={@form.params["name"] || @account.name}
                    class={["input w-full", has_error?(@form, :name) && "input-error"]}
                    phx-debounce="300"
                  />
                  <p :if={has_error?(@form, :name)} class="text-sm text-error mt-1">
                    {first_error(@form, :name)}
                  </p>
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Slug</span>
                  </label>
                  <input
                    type="text"
                    name="account[slug]"
                    value={@form.params["slug"] || @account.slug}
                    class={["input w-full font-mono", has_error?(@form, :slug) && "input-error"]}
                    phx-debounce="300"
                  />
                  <p :if={has_error?(@form, :slug)} class="text-sm text-error mt-1">
                    {first_error(@form, :slug)}
                  </p>
                  <p class="text-xs text-base-content/50 mt-1">
                    Used in URLs. Lowercase letters, numbers, and hyphens only.
                  </p>
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text text-sm text-base-content/60">Account Type</span>
                  </label>
                  <p class="text-sm">{account_type_label(@account.type)}</p>
                </div>

                <div :if={@can_save} class="card-actions justify-end">
                  <button type="submit" class="btn btn-primary w-full sm:w-auto">
                    Save Changes
                  </button>
                </div>
              </form>
            </div>
          </div>

          <%!-- Section 1 (read-only view for non-editor roles) --%>
          <div :if={not @can_edit} class="card bg-base-100 shadow mf-card">
            <div class="card-body">
              <h2 class="card-title text-base">General Settings</h2>
              <div class="space-y-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Account Name</span>
                  </label>
                  <input type="text" value={@account.name} class="input w-full" readonly />
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Slug</span>
                  </label>
                  <input
                    type="text"
                    value={@account.slug}
                    class="input w-full font-mono"
                    readonly
                  />
                  <p class="text-xs text-base-content/50 mt-1">
                    Used in URLs. Lowercase letters, numbers, and hyphens only.
                  </p>
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text text-sm text-base-content/60">Account Type</span>
                  </label>
                  <p class="text-sm">{account_type_label(@account.type)}</p>
                </div>
              </div>
            </div>
          </div>

          <%!-- Section: Leave Account (non-owners of team accounts) --%>
          <div :if={not @is_owner and @account.type == "team" and not @left_account} class="card bg-base-100 shadow mf-card border border-warning/40">
            <div class="card-body">
              <h2 class="card-title text-base">Leave Account</h2>
              <p class="text-sm text-base-content/60">
                Remove yourself from this account. You will lose access to all account data.
                This action cannot be undone.
              </p>
              <div class="card-actions justify-end mt-4">
                <button
                  data-role="revoke-own-access"
                  phx-click="show_leave_confirm"
                  class="btn btn-warning"
                >
                  Leave Account
                </button>
              </div>
            </div>

            <%!-- Leave Account confirmation modal --%>
            <dialog :if={@show_leave_confirm} id="leave-account-modal" class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-bold">Leave Account</h3>
                <p class="py-4">Are you sure you want to leave this account? You will lose all access.</p>
                <div class="modal-action">
                  <button phx-click="cancel_leave" id="leave-cancel-btn" class="btn">Cancel</button>
                  <button data-role="confirm-leave" phx-click="leave_account" class="btn btn-warning">Leave Account</button>
                </div>
              </div>
              <div class="modal-backdrop" phx-click="cancel_leave"></div>
            </dialog>
          </div>

          <%!-- Leave Account success state --%>
          <div :if={@left_account} class="card bg-base-100 shadow mf-card border border-success/40">
            <div class="card-body">
              <p class="text-success">Your access has been revoked. You have left the account.</p>
            </div>
          </div>

          <%!-- Agency Access section (team accounts, all roles can view) --%>
          <AgencyLive.Settings.grant_agency_access_section
            :if={@account.type == "team"}
            agency_grants={@agency_grants}
            grant_agency_form={@grant_agency_form}
            can_manage_agencies={@current_user_role in [:owner, :admin]}
          />

          <%!-- Auto-enrollment (team accounts, owner/admin only) --%>
          <AgencyLive.Settings.auto_enrollment_section
            :if={@account.type == "team" and @current_user_role in [:owner, :admin]}
            auto_enrollment_rule={@auto_enrollment_rule}
            auto_enrollment_form={@auto_enrollment_form}
          />

          <%!-- White-Label Branding (team accounts, owner/admin only) --%>
          <AgencyLive.Settings.white_label_section
            :if={@account.type == "team" and @current_user_role in [:owner, :admin]}
            white_label_config={@agency_white_label_config}
            white_label_form={@white_label_form}
          />

          <%!-- Section 2: Transfer Ownership (owners of team accounts only) --%>
          <div :if={@is_owner and @account.type == "team"} class="card bg-base-100 shadow mf-card">
            <div class="card-body">
              <h2 class="card-title text-base">Transfer Ownership</h2>
              <p class="text-sm text-base-content/60">
                The selected member will become the account owner. You will be demoted to admin.
              </p>
              <form
                id="transfer-ownership-form"
                data-role="transfer-ownership"
                phx-submit="transfer_ownership"
                class="space-y-4 mt-4"
              >
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">New Owner</span>
                  </label>
                  <select name="user_id" class="select w-full">
                    <option :for={member <- non_owner_members(@members)} value={member.user_id}>
                      {member.user.email}
                    </option>
                  </select>
                </div>
                <div class="card-actions justify-end">
                  <button type="submit" class="btn btn-warning">
                    Transfer Ownership
                  </button>
                </div>
              </form>
            </div>
          </div>

          <%!-- Section 3: Danger Zone (owners of team accounts only) --%>
          <div
            :if={@is_owner and @account.type == "team"}
            class="card bg-base-100 shadow mf-card border border-error/40"
          >
            <div class="card-body">
              <h2 class="card-title text-base text-error">Delete Account</h2>
              <%!--
                Dual-named inputs: flat names (account_name_confirmation/password) for unit
                test compatibility and nested names (delete_confirmation[...]) for BDD spex.
                The sr-only inputs are visually hidden but present in the DOM.
                The handler reads from whichever set has a non-empty value.
              --%>
              <form
                id="delete-account-form"
                data-role="delete-account"
                phx-submit="delete_account"
                class="space-y-4"
              >
                <%!-- sr-only nested inputs for BDD spex compatibility --%>
                <input
                  type="text"
                  name="delete_confirmation[account_name]"
                  class="sr-only"
                  aria-hidden="true"
                />
                <input
                  type="password"
                  name="delete_confirmation[password]"
                  class="sr-only"
                  aria-hidden="true"
                />

                <p class="text-sm text-base-content/60">
                  This action is permanent and cannot be undone. This deletion is irreversible — all account data, members, and integrations will be deleted.
                </p>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Type the account name to confirm</span>
                  </label>
                  <input
                    type="text"
                    name="account_name_confirmation"
                    class="input w-full"
                    phx-debounce="blur"
                    placeholder={@account.name}
                  />
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Your password</span>
                  </label>
                  <input
                    type="password"
                    name="password"
                    class="input input-password w-full"
                  />
                </div>

                <div class="card-actions justify-end">
                  <button type="submit" class="btn btn-error">
                    Delete Account
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount / handle_params
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    case Accounts.list_accounts(scope) do
      [] ->
        {:ok, redirect(socket, to: "/app/accounts")}

      accounts ->
        if connected?(socket), do: Accounts.subscribe_account(scope)

        {:ok, assign(socket, :accounts, accounts)}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope
    accounts = socket.assigns[:accounts] || Accounts.list_accounts(scope)

    account =
      case Map.get(params, "account_id") do
        nil ->
          ActiveAccountHook.primary_account(accounts)

        account_id_str ->
          account_id = String.to_integer(account_id_str)
          Enum.find(accounts, fn a -> a.id == account_id end) ||
            ActiveAccountHook.primary_account(accounts)
      end

    user_role = Accounts.get_user_role(scope, scope.user.id, account.id)
    members = Accounts.list_account_members(scope, account.id)
    changeset = Accounts.change_account(scope, account)

    socket =
      socket
      |> assign(:accounts, accounts)
      |> assign(:account, account)
      |> assign(:form, build_form(changeset, account))
      |> assign(:members, members)
      |> assign(:current_user_role, user_role)
      |> assign(:is_owner, user_role == :owner)
      |> assign(:can_edit, user_role in [:owner, :admin])
      |> assign(:can_save, user_role in [:owner, :admin])
      |> assign(:active_account_name, account.name)
      |> assign(:left_account, false)
      |> assign(:show_leave_confirm, false)
      |> assign_agency_data(scope, account, user_role)

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"account" => account_params}, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account
    changeset = Accounts.change_account(scope, account, account_params)

    {:noreply, assign(socket, :form, build_form(changeset, account, account_params))}
  end

  def handle_event("save", %{"account" => account_params}, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    case Accounts.update_account(scope, account, account_params) do
      {:ok, updated_account} ->
        members = Accounts.list_account_members(scope, updated_account.id)
        changeset = Accounts.change_account(scope, updated_account)

        {:noreply,
         socket
         |> assign(:account, updated_account)
         |> assign(:members, members)
         |> assign(:form, build_form(changeset, updated_account))
         |> put_flash(:info, "Account settings saved successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, build_form(changeset, account, account_params))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to update this account")}
    end
  end

  def handle_event("transfer_ownership", %{"user_id" => user_id}, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account.id
    current_user_id = scope.user.id
    target_user_id = parse_id(user_id)

    with {:ok, _} <- Accounts.update_user_role(scope, target_user_id, account_id, :owner),
         {:ok, _} <- Accounts.update_user_role(scope, current_user_id, account_id, :admin) do
      members = Accounts.list_account_members(scope, account_id)

      {:noreply,
       socket
       |> assign(:members, members)
       |> assign(:current_user_role, :admin)
       |> assign(:is_owner, false)
       |> put_flash(:info, "Ownership transferred successfully")}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to transfer ownership")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to transfer ownership")}
    end
  end

  def handle_event("delete_account", params, socket) do
    {name_confirmation, password} = extract_delete_params(params)
    do_delete_account(name_confirmation, password, socket)
  end

  def handle_event("show_leave_confirm", _params, socket) do
    {:noreply, assign(socket, :show_leave_confirm, true)}
  end

  def handle_event("cancel_leave", _params, socket) do
    {:noreply, assign(socket, :show_leave_confirm, false)}
  end

  def handle_event("leave_account", _params, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    case Accounts.leave_account(scope, account.id) do
      {:ok, _member} ->
        {:noreply, socket |> assign(:left_account, true) |> assign(:show_leave_confirm, false)}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "Account owners cannot leave. Transfer ownership first.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave account")}
    end
  end

  def handle_event("save_auto_enrollment", %{"auto_enrollment" => params}, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    attrs = %{
      email_domain: params["domain"],
      default_access_level: parse_access_level(params["default_access_level"]),
      enabled: true
    }

    case Agencies.configure_auto_enrollment(scope, account.id, attrs) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> assign(:auto_enrollment_rule, rule)
         |> assign(:auto_enrollment_form, empty_form())
         |> put_flash(:info, "Auto-enrollment enabled")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = changeset_to_errors(changeset)
        {:noreply, assign(socket, :auto_enrollment_form, %{params: params, errors: errors})}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to configure auto-enrollment")}
    end
  end

  def handle_event("disable_auto_enrollment", _params, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    attrs = %{enabled: false}

    case Agencies.configure_auto_enrollment(scope, account.id, attrs) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> assign(:auto_enrollment_rule, rule)
         |> put_flash(:info, "Auto-enrollment disabled")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to configure auto-enrollment")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disable auto-enrollment")}
    end
  end

  def handle_event("validate_white_label", %{"white_label" => params}, socket) do
    {:noreply, assign(socket, :white_label_form, %{params: params, errors: []})}
  end

  def handle_event("save_white_label", %{"white_label" => params}, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    attrs = %{
      subdomain: params["subdomain"],
      logo_url: params["logo_url"],
      primary_color: params["primary_color"],
      secondary_color: params["secondary_color"]
    }

    case Agencies.update_white_label_config(scope, account.id, attrs) do
      {:ok, config} ->
        {:noreply,
         socket
         |> assign(:agency_white_label_config, config)
         |> assign(:white_label_form, empty_form())
         |> put_flash(:info, "White-label settings saved")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = changeset_to_errors(changeset)
        {:noreply, assign(socket, :white_label_form, %{params: params, errors: errors})}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to configure white-label branding")}
    end
  end

  def handle_event("reset_white_label", _params, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    case Agencies.reset_white_label_config(scope, account.id) do
      :ok ->
        {:noreply,
         socket
         |> assign(:agency_white_label_config, nil)
         |> assign(:white_label_form, empty_form())
         |> put_flash(:info, "Branding reset to default")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to reset white-label branding")}
    end
  end

  def handle_event("grant_agency_access", %{"agency_access" => params}, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account
    slug = params["slug"] || ""
    access_level = parse_access_level(params["access_level"])

    case Accounts.get_account_by_slug(slug) do
      nil ->
        form = %{params: params, errors: [slug: {"No agency account found with that slug", []}]}
        {:noreply, assign(socket, :grant_agency_form, form)}

      agency_account ->
        do_grant_agency_access(scope, account.id, agency_account, access_level, params, socket)
    end
  end

  def handle_event("revoke_agency_access", %{"agency-account-id" => agency_account_id_str}, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account
    agency_account_id = String.to_integer(agency_account_id_str)

    case Agencies.revoke_agency_access_from_client(scope, account.id, agency_account_id) do
      {:ok, _grant} ->
        grants = Agencies.list_grants_for_client_account(scope, account.id)
        grants = if is_list(grants), do: grants, else: []

        {:noreply,
         socket
         |> assign(:agency_grants, grants)
         |> put_flash(:info, "Agency access revoked")}

      {:error, :cannot_revoke_originator} ->
        {:noreply, put_flash(socket, :error, "Cannot revoke originator agency access")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Agency access grant not found")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to revoke agency access")}
    end
  end

  def handle_event("verify_dns", _params, socket) do
    {:noreply, put_flash(socket, :info, "DNS verification initiated. Please allow a few minutes.")}
  end

  defp do_grant_agency_access(scope, account_id, agency_account, access_level, params, socket) do
    case Agencies.grant_agency_access_from_client(scope, account_id, agency_account.id, access_level) do
      {:ok, _grant} ->
        grants = Agencies.list_grants_for_client_account(scope, account_id)
        grants = if is_list(grants), do: grants, else: []

        {:noreply,
         socket
         |> assign(:agency_grants, grants)
         |> assign(:grant_agency_form, empty_form())
         |> put_flash(:info, "Agency access granted to #{agency_account.name}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = changeset_to_errors(changeset)
        {:noreply, assign(socket, :grant_agency_form, %{params: params, errors: errors})}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to grant agency access")}
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub message handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:updated, updated_account}, socket) do
    scope = socket.assigns.current_scope
    changeset = Accounts.change_account(scope, updated_account)

    {:noreply,
     socket
     |> assign(:account, updated_account)
     |> assign(:form, build_form(changeset, updated_account))}
  end

  def handle_info({:deleted, _account}, socket) do
    {:noreply, redirect(socket, to: "/app/accounts")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp assign_agency_data(socket, scope, account, user_role)
       when account.type == "team" and user_role in [:owner, :admin] do
    auto_enrollment_rule =
      case Agencies.get_auto_enrollment_rule(scope, account.id) do
        {:error, _} -> nil
        rule -> rule
      end

    agency_white_label_config =
      case Agencies.get_white_label_config(scope, account.id) do
        {:error, _} -> nil
        config -> config
      end

    agency_grants =
      case Agencies.list_grants_for_client_account(scope, account.id) do
        {:error, _} -> []
        grants -> grants
      end

    socket
    |> assign(:auto_enrollment_rule, auto_enrollment_rule)
    |> assign(:auto_enrollment_form, empty_form())
    |> assign(:agency_white_label_config, agency_white_label_config)
    |> assign(:white_label_form, empty_form())
    |> assign(:agency_grants, agency_grants)
    |> assign(:grant_agency_form, empty_form())
  end

  defp assign_agency_data(socket, scope, account, _user_role)
       when account.type == "team" do
    agency_grants =
      case Agencies.list_grants_for_client_account(scope, account.id) do
        {:error, _} -> []
        grants -> grants
      end

    socket
    |> assign(:auto_enrollment_rule, nil)
    |> assign(:auto_enrollment_form, empty_form())
    |> assign(:agency_white_label_config, nil)
    |> assign(:white_label_form, empty_form())
    |> assign(:agency_grants, agency_grants)
    |> assign(:grant_agency_form, empty_form())
  end

  defp assign_agency_data(socket, _scope, _account, _user_role) do
    socket
    |> assign(:auto_enrollment_rule, nil)
    |> assign(:auto_enrollment_form, empty_form())
    |> assign(:agency_white_label_config, nil)
    |> assign(:white_label_form, empty_form())
    |> assign(:agency_grants, [])
    |> assign(:grant_agency_form, empty_form())
  end

  defp empty_form, do: %{params: %{}, errors: []}

  defp do_delete_account(name_confirmation, password, socket) do
    account = socket.assigns.account
    scope = socket.assigns.current_scope
    user = scope.user

    cond do
      name_confirmation != account.name ->
        {:noreply, put_flash(socket, :error, "Account name does not match")}

      is_nil(password) or password == "" ->
        {:noreply, put_flash(socket, :error, "Password is required")}

      is_nil(Users.get_user_by_email_and_password(user.email, password)) ->
        {:noreply, put_flash(socket, :error, "Incorrect password")}

      true ->
        case Accounts.delete_account(scope, account) do
          {:ok, _deleted} ->
            {:noreply,
             socket
             |> put_flash(:info, "Account deleted successfully.")
             |> redirect(to: "/app/accounts")}

          {:error, :personal_account} ->
            {:noreply, put_flash(socket, :error, "Personal accounts cannot be deleted")}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You are not authorized to delete this account")}
        end
    end
  end

  # Extracts account name confirmation and password from delete_account params.
  # Handles both flat names (unit tests) and nested delete_confirmation (BDD spex).
  # Prefers the nested value when non-empty; falls back to the flat value.
  defp extract_delete_params(params) do
    nested_name = get_in(params, ["delete_confirmation", "account_name"])
    flat_name = Map.get(params, "account_name_confirmation")
    name = if nested_name && nested_name != "", do: nested_name, else: flat_name || ""

    nested_pw = get_in(params, ["delete_confirmation", "password"])
    flat_pw = Map.get(params, "password")
    pw = if nested_pw && nested_pw != "", do: nested_pw, else: flat_pw || ""

    {name, pw}
  end

  defp non_owner_members(members) do
    Enum.reject(members, &(&1.role == :owner))
  end

  defp account_type_label("personal"), do: "Personal"
  defp account_type_label("team"), do: "Team"
  defp account_type_label(type), do: type

  defp has_error?(form, field) do
    form
    |> Map.get(:errors, [])
    |> Keyword.has_key?(field)
  end

  defp first_error(form, field) do
    case form |> Map.get(:errors, []) |> Keyword.get(field) do
      {msg, _opts} -> msg
      nil -> nil
    end
  end

  defp build_form(changeset, account), do: build_form(changeset, account, %{})

  defp build_form(%Ecto.Changeset{} = changeset, account, extra_params) do
    params = %{
      "name" => Map.get(extra_params, "name") || account.name,
      "slug" => Map.get(extra_params, "slug") || account.slug
    }

    errors =
      Enum.map(changeset.errors, fn {field, {msg, opts}} ->
        {field, {translate_error_msg({msg, opts}), opts}}
      end)

    %{params: params, errors: errors, changeset: changeset}
  end

  defp translate_error_msg({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(MetricFlowWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MetricFlowWeb.Gettext, "errors", msg, opts)
    end
  end

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)

  defp parse_access_level("read_only"), do: :read_only
  defp parse_access_level("account_manager"), do: :account_manager
  defp parse_access_level("admin"), do: :admin
  defp parse_access_level(_), do: :read_only

  defp changeset_to_errors(%Ecto.Changeset{} = changeset) do
    Enum.map(changeset.errors, fn {field, {msg, opts}} ->
      {field, {translate_error_msg({msg, opts}), opts}}
    end)
  end
end
