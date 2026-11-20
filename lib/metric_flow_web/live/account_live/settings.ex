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
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
      active_account_type={assigns[:active_account_type]}
    >
      <div class="mx-auto max-w-3xl space-y-6 overflow-x-hidden">
        <header class="space-y-1">
          <h1 class="text-2xl font-semibold text-base-content break-words">Account Settings</h1>
          <p class="text-sm text-base-content/70 break-words">{@account.name}</p>
        </header>

        <%!-- Account — name, slug, type. Owners and admins can edit. --%>
        <section :if={@can_edit} class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6">
          <header class="space-y-1">
            <h2 class="text-lg font-semibold text-base-content">Account</h2>
            <p class="text-sm text-base-content/70">
              The name and slug shown to teammates and anywhere this account is referenced.
            </p>
          </header>
          <form
            id="account-settings-form"
            phx-change="validate"
            phx-submit="save"
            class="mt-4 space-y-4"
          >
            <div class="space-y-1">
              <label for="account-name-input" class="block text-sm font-semibold text-base-content">
                Account Name
              </label>
              <input
                id="account-name-input"
                type="text"
                name="account[name]"
                value={@form.params["name"] || @account.name}
                class={[
                  "input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content",
                  has_error?(@form, :name) && "input-error"
                ]}
                phx-debounce="300"
              />
              <p :if={has_error?(@form, :name)} class="text-sm text-error">
                {first_error(@form, :name)}
              </p>
            </div>

            <div class="space-y-1">
              <label for="account-slug-input" class="block text-sm font-semibold text-base-content">
                Slug
              </label>
              <input
                id="account-slug-input"
                type="text"
                name="account[slug]"
                value={@form.params["slug"] || @account.slug}
                class={[
                  "input input-bordered w-full font-mono bg-base-100 border-neutral rounded-box text-base-content",
                  has_error?(@form, :slug) && "input-error"
                ]}
                phx-debounce="300"
              />
              <p :if={has_error?(@form, :slug)} class="text-sm text-error">
                {first_error(@form, :slug)}
              </p>
              <p class="text-xs text-base-content/60">
                Used in URLs. Lowercase letters, numbers, and hyphens only.
              </p>
            </div>

            <div class="space-y-1">
              <span class="block text-sm font-semibold text-base-content">Account Type</span>
              <p class="text-sm text-base-content/70">{account_type_label(@account.type)}</p>
            </div>

            <div :if={@can_save}>
              <button
                type="submit"
                class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
              >
                Save Changes
              </button>
            </div>
          </form>
        </section>

        <%!-- Account (read-only view for non-editor roles) --%>
        <section
          :if={not @can_edit}
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <header class="space-y-1">
            <h2 class="text-lg font-semibold text-base-content">Account</h2>
            <p class="text-sm text-base-content/70">
              These details are read-only at your access level.
            </p>
          </header>
          <div class="mt-4 space-y-4">
            <div class="space-y-1">
              <span class="block text-sm font-semibold text-base-content">Account Name</span>
              <input
                type="text"
                value={@account.name}
                class="input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
                readonly
              />
            </div>
            <div class="space-y-1">
              <span class="block text-sm font-semibold text-base-content">Slug</span>
              <input
                type="text"
                value={@account.slug}
                class="input input-bordered w-full font-mono bg-base-100 border-neutral rounded-box text-base-content"
                readonly
              />
              <p class="text-xs text-base-content/60">
                Used in URLs. Lowercase letters, numbers, and hyphens only.
              </p>
            </div>
            <div class="space-y-1">
              <span class="block text-sm font-semibold text-base-content">Account Type</span>
              <p class="text-sm text-base-content/70">{account_type_label(@account.type)}</p>
            </div>
          </div>
        </section>

        <%!-- Agency Access section (team accounts, all roles can view) --%>
        <AgencyLive.Settings.grant_agency_access_section
          :if={@account.type in [:client, :agency]}
          agency_grants={@agency_grants}
          grant_agency_form={@grant_agency_form}
          can_manage_agencies={@current_user_role in [:owner, :admin]}
        />

        <%!-- Agency configuration: auto-enrollment and white-label branding
           (agency-type team accounts, owners/admins only) --%>
        <AgencyLive.Settings.auto_enrollment_section
          :if={@account.type == :agency and @current_user_role in [:owner, :admin]}
          auto_enrollment_rule={@auto_enrollment_rule}
          auto_enrollment_form={@auto_enrollment_form}
        />

        <AgencyLive.Settings.white_label_section
          :if={@account.type == :agency and @current_user_role in [:owner, :admin]}
          white_label_config={@agency_white_label_config}
          white_label_form={@white_label_form}
          logo_upload={@uploads.logo}
          pending_logo={@pending_logo}
        />

        <%!-- Transfer Ownership (owners of team accounts) --%>
        <section
          :if={@is_owner and @account.type in [:client, :agency]}
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <header class="space-y-1">
            <h2 class="text-lg font-semibold text-base-content">Transfer Ownership</h2>
            <p class="text-sm text-base-content/70">
              The new owner must confirm by email before ownership actually changes.
            </p>
          </header>

          <div
            :if={@pending_transfer}
            data-role="transfer-pending-banner"
            class="mt-4 rounded-box border border-warning bg-base-200 p-3 text-sm text-warning break-words"
          >
            A transfer to <strong>{@pending_transfer.target_email}</strong> is pending confirmation.
          </div>

          <form
            id="transfer-ownership-form"
            data-role="transfer-ownership"
            phx-submit="transfer_ownership"
            class="mt-4 space-y-4"
          >
            <div class="space-y-2">
              <label class="flex cursor-pointer items-start gap-2">
                <input
                  type="radio"
                  name="transfer_target"
                  value="existing"
                  data-role="transfer-target-existing-radio"
                  class="radio radio-sm mt-1"
                  checked
                />
                <span class="text-sm text-base-content">
                  Transfer to an existing member with access
                </span>
              </label>
              <select
                name="user_id"
                class="select select-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
              >
                <option :for={member <- non_owner_members(@members)} value={member.user_id}>
                  {member.user.email}
                </option>
              </select>
            </div>

            <div class="space-y-2">
              <label class="flex cursor-pointer items-start gap-2">
                <input
                  type="radio"
                  name="transfer_target"
                  value="invite"
                  data-role="transfer-target-invite-radio"
                  class="radio radio-sm mt-1"
                />
                <span class="text-sm text-base-content">
                  Send a transfer invitation to a new email
                </span>
              </label>
              <input
                type="email"
                name="invite_email"
                data-role="transfer-invite-email-input"
                placeholder="newowner@example.com"
                class="input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
              />
            </div>

            <label class="flex cursor-pointer items-start gap-2">
              <input type="hidden" name="make_copy" value="false" />
              <input
                type="checkbox"
                name="make_copy"
                value="true"
                data-role="transfer-make-copy-checkbox"
                class="checkbox checkbox-sm mt-1"
              />
              <span class="text-sm text-base-content">
                Make a copy of this account's data in my own account
              </span>
            </label>

            <label class="flex cursor-pointer items-start gap-2">
              <input type="hidden" name="remain_admin" value="false" />
              <input
                type="checkbox"
                name="remain_admin"
                value="true"
                data-role="transfer-remain-admin-checkbox"
                class="checkbox checkbox-sm mt-1"
              />
              <span class="text-sm text-base-content">Remain as admin after the transfer</span>
            </label>

            <label
              :if={@account_has_originator_grants}
              class="flex cursor-pointer items-start gap-2"
            >
              <input type="hidden" name="transfer_originator" value="false" />
              <input
                type="checkbox"
                name="transfer_originator"
                value="true"
                data-role="transfer-originator-checkbox"
                class="checkbox checkbox-sm mt-1"
              />
              <span class="text-sm text-base-content">
                Also transfer white-label originator status
              </span>
            </label>

            <div>
              <button
                type="submit"
                class="rounded-box border border-warning bg-base-200 px-4 py-2 text-sm font-semibold text-warning hover:bg-base-300 w-full sm:w-auto"
              >
                Transfer Ownership
              </button>
            </div>
          </form>

          <div
            :if={@ownership_transfer_log}
            data-role="ownership-transfer-log-entry"
            class="mt-4 text-xs text-base-content/60 break-words"
          >
            Ownership transferred from {@ownership_transfer_log.initiated_by_email} to {@ownership_transfer_log.target_email}, confirmed {@ownership_transfer_log.confirmed_at}.
          </div>
        </section>

        <%!-- Leave Account (non-owners of team accounts).
             A destructive self-action: kept in its own warning-toned card so it is
             clearly separated from everyday read/edit controls. --%>
        <section
          :if={not @is_owner and @account.type in [:client, :agency] and not @left_account}
          class="rounded-box border border-warning bg-base-200 p-4 sm:p-6"
        >
          <header class="space-y-1">
            <h2 class="text-lg font-semibold text-warning">Leave Account</h2>
            <p class="text-sm text-base-content/70">
              Remove yourself from this account. You will lose access to all account data.
              This action cannot be undone.
            </p>
          </header>
          <div class="mt-4">
            <button
              data-role="revoke-own-access"
              phx-click="show_leave_confirm"
              class="rounded-box border border-warning bg-base-200 px-4 py-2 text-sm font-semibold text-warning hover:bg-base-300 w-full sm:w-auto"
            >
              Leave Account
            </button>
          </div>

          <dialog :if={@show_leave_confirm} id="leave-account-modal" class="modal modal-open">
            <div class="modal-box rounded-box border border-neutral bg-base-200">
              <h3 class="text-lg font-semibold text-base-content">Leave Account</h3>
              <p class="py-4 text-sm text-base-content/70">
                Are you sure you want to leave this account? You will lose all access.
              </p>
              <div class="modal-action flex-wrap gap-2">
                <button
                  phx-click="cancel_leave"
                  id="leave-cancel-btn"
                  class="rounded-box border border-neutral bg-base-200 px-4 py-2 text-sm text-base-content hover:bg-base-300"
                >
                  Cancel
                </button>
                <button
                  data-role="confirm-leave"
                  phx-click="leave_account"
                  class="rounded-box border border-warning bg-base-200 px-4 py-2 text-sm font-semibold text-warning hover:bg-base-300"
                >
                  Leave Account
                </button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="cancel_leave"></div>
          </dialog>
        </section>

        <section
          :if={@left_account}
          class="rounded-box border border-success bg-base-200 p-4 sm:p-6"
        >
          <p class="text-sm text-success">
            Your access has been revoked. You have left the account.
          </p>
        </section>

        <%!-- Danger zone — visibly separated from everyday settings.
             Deletion is irreversible, so it sits below an error-toned divider
             and inside an error-bordered card of its own. --%>
        <div :if={@is_owner and @account.type in [:client, :agency]} class="pt-6 space-y-3">
          <div class="flex items-center gap-3">
            <span aria-hidden="true" class="h-px flex-1 bg-error/40"></span>
            <span class="text-xs font-semibold uppercase tracking-wider text-error">
              Danger zone
            </span>
            <span aria-hidden="true" class="h-px flex-1 bg-error/40"></span>
          </div>

          <section class="rounded-box border border-error bg-base-200 p-4 sm:p-6">
            <header class="space-y-1">
              <h2 class="text-lg font-semibold text-error">Delete Account</h2>
              <p class="text-sm text-base-content/70">
                This action is permanent and cannot be undone. This deletion is irreversible — all account data, members, and integrations will be deleted.
              </p>
            </header>
            <%!--
              Dual-named inputs: flat names (account_name_confirmation/password) for unit
              test compatibility and nested names (delete_confirmation[...]) for BDD spex.
              The sr-only inputs are visually hidden but present in the DOM. The handler
              reads from whichever set has a non-empty value.
            --%>
            <form
              id="delete-account-form"
              data-role="delete-account"
              phx-submit="delete_account"
              class="mt-4 space-y-4"
            >
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

              <p class="text-sm text-base-content/70">
                This action is permanent and cannot be undone. This deletion is irreversible — all account data, members, and integrations will be deleted.
              </p>

              <div class="space-y-1">
                <label
                  for="delete-account-name"
                  class="block text-sm font-semibold text-base-content"
                >
                  Type the account name to confirm
                </label>
                <input
                  id="delete-account-name"
                  type="text"
                  name="account_name_confirmation"
                  class="input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
                  phx-debounce="blur"
                  placeholder={@account.name}
                />
              </div>

              <div class="space-y-1">
                <label
                  for="delete-account-password"
                  class="block text-sm font-semibold text-base-content"
                >
                  Your password
                </label>
                <input
                  id="delete-account-password"
                  type="password"
                  name="password"
                  class="input input-bordered input-password w-full bg-base-100 border-neutral rounded-box text-base-content"
                />
              </div>

              <button
                type="submit"
                class="rounded-box border border-error bg-base-200 px-4 py-2 text-sm font-semibold text-error hover:bg-base-300 w-full sm:w-auto"
              >
                Delete Account
              </button>
            </form>
          </section>
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

        {:ok, socket |> assign(:accounts, accounts) |> AgencyLive.LogoUpload.configure()}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope
    accounts = socket.assigns[:accounts] || Accounts.list_accounts(scope)

    account =
      case Map.get(params, "account_id") do
        nil ->
          ActiveAccountHook.active_account(accounts, scope.user)

        account_id_str ->
          account_id = String.to_integer(account_id_str)

          Enum.find(accounts, fn a -> a.id == account_id end) ||
            ActiveAccountHook.active_account(accounts, scope.user)
      end

    user_role = Accounts.get_user_role(scope, scope.user.id, account.id)
    members = Accounts.list_account_members(scope, account.id)
    changeset = Accounts.change_account(scope, account)

    socket =
      socket
      |> assign(:accounts, accounts)
      |> AgencyLive.LogoUpload.clear()
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
      |> assign_ownership_transfer_data(scope, account)

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

  def handle_event("transfer_ownership", params, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    case Accounts.initiate_ownership_transfer(scope, account.id, params) do
      {:ok, transfer} ->
        {:noreply,
         socket
         |> assign(:pending_transfer, transfer)
         |> put_flash(
           :info,
           "Ownership transfer initiated. Waiting for confirmation from #{transfer.target_email}."
         )}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to transfer ownership")}

      {:error, :invalid_target} ->
        {:noreply,
         put_flash(socket, :error, "Select a member or enter an email to transfer ownership to.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Failed to initiate ownership transfer")}
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

  def handle_event("save_auto_enrollment", %{"auto_enrollment" => params}, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    attrs = %{
      email_domain: params["domain"] || "",
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
        {:noreply,
         put_flash(socket, :error, "You are not authorized to configure auto-enrollment")}
    end
  end

  def handle_event("disable_auto_enrollment", _params, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    case Agencies.configure_auto_enrollment(scope, account.id, %{enabled: false}) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> assign(:auto_enrollment_rule, rule)
         |> put_flash(:info, "Auto-enrollment disabled")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You are not authorized to configure auto-enrollment")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disable auto-enrollment")}
    end
  end

  def handle_event("save_white_label", %{"white_label" => params}, socket) do
    params = AgencyLive.LogoUpload.merge_params(socket, params)
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    attrs = %{
      subdomain: params["subdomain"] || "",
      custom_domain: params["custom_domain"],
      logo_url: params["logo_url"],
      primary_color: params["primary_color"],
      secondary_color: params["secondary_color"],
      accent_color: params["accent_color"]
    }

    case Agencies.update_white_label_config(scope, account.id, attrs) do
      {:ok, config} ->
        {:noreply,
         socket
         |> assign(:agency_white_label_config, config)
         |> assign(:white_label_form, empty_form())
         |> AgencyLive.LogoUpload.clear()
         |> put_flash(:info, "White-label settings saved")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = changeset_to_errors(changeset)
        {:noreply, assign(socket, :white_label_form, %{params: params, errors: errors})}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You are not authorized to configure white-label branding")}
    end
  end

  def handle_event("validate_white_label", %{"white_label" => params}, socket) do
    {:noreply, assign(socket, :white_label_form, %{params: params, errors: []})}
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
         |> AgencyLive.LogoUpload.clear()
         |> put_flash(:info, "Branding reset to default")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You are not authorized to reset white-label branding")}
    end
  end

  def handle_event("verify_dns", _params, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account

    case Agencies.verify_dns(scope, account.id) do
      {:ok, _results} ->
        config = unwrap(Agencies.get_white_label_config(scope, account.id))

        {:noreply,
         socket
         |> assign(:agency_white_label_config, config)
         |> put_flash(:info, "DNS verification complete")}

      {:error, :no_config} ->
        {:noreply, put_flash(socket, :error, "No white-label configuration to verify")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to verify DNS")}
    end
  end

  def handle_event(
        "revoke_agency_access",
        %{"agency-account-id" => agency_account_id_str},
        socket
      ) do
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

  defp do_grant_agency_access(scope, account_id, agency_account, access_level, params, socket) do
    case Agencies.grant_agency_access_from_client(
           scope,
           account_id,
           agency_account.id,
           access_level
         ) do
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

  # Swoosh's test adapter delivers to the calling process. Initiating an
  # ownership transfer sends email synchronously from this LiveView (it
  # doesn't redirect away afterward, unlike account deletion), so this
  # process receives the delivery notice directly and must not crash on it.
  def handle_info({:email, %Swoosh.Email{}}, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp assign_agency_data(socket, scope, account, user_role) do
    agency_grants =
      case Agencies.list_grants_for_client_account(scope, account.id) do
        {:error, _} -> []
        grants -> grants
      end

    {auto_enrollment_rule, agency_white_label_config} = agency_config(scope, account, user_role)

    socket
    |> assign(:agency_grants, agency_grants)
    |> assign(:grant_agency_form, empty_form())
    |> assign(:auto_enrollment_rule, auto_enrollment_rule)
    |> assign(:auto_enrollment_form, empty_form())
    |> assign(:agency_white_label_config, agency_white_label_config)
    |> assign(:white_label_form, empty_form())
  end

  defp agency_config(scope, %{type: :agency, id: agency_id}, role)
       when role in [:owner, :admin] do
    {unwrap(Agencies.get_auto_enrollment_rule(scope, agency_id)),
     unwrap(Agencies.get_white_label_config(scope, agency_id))}
  end

  defp agency_config(_scope, _account, _role), do: {nil, nil}

  defp assign_ownership_transfer_data(socket, scope, account) do
    pending_transfer =
      case Accounts.get_pending_ownership_transfer(scope, account.id) do
        {:ok, transfer} -> transfer
        {:error, :not_found} -> nil
      end

    ownership_transfer_log =
      case Accounts.get_latest_completed_ownership_transfer(scope, account.id) do
        {:ok, transfer} -> transfer
        {:error, :not_found} -> nil
      end

    socket
    |> assign(:pending_transfer, pending_transfer)
    |> assign(:ownership_transfer_log, ownership_transfer_log)
    |> assign(:account_has_originator_grants, account_has_originator_grants?(scope, account))
  end

  defp account_has_originator_grants?(scope, account) do
    case Agencies.list_agency_client_accounts(scope, account.id) do
      grants when is_list(grants) -> Enum.any?(grants, &(&1.origination_status == :originator))
      {:error, _} -> false
    end
  end

  defp unwrap({:error, _}), do: nil
  defp unwrap(value), do: value

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

  defp account_type_label(:client), do: "Client"
  defp account_type_label(:agency), do: "Agency"
  defp account_type_label(type), do: to_string(type)

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
