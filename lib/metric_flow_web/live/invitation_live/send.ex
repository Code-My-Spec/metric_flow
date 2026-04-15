defmodule MetricFlowWeb.InvitationLive.Send do
  @moduledoc """
  Send email invitations to grant access to the active account.

  Displays a send-invitation form and a list of pending invitations. Only owners
  and admins of the active account may access this page. Invitations are sent to
  any email address — the recipient does not need an existing account. Pending
  invitations can be cancelled by the inviting user, an owner, or an admin.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
  alias MetricFlow.Invitations

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
    <div class="mf-content">
      <div class="flex items-center gap-4 mb-6">
        <a href="/app/accounts/members" class="btn btn-ghost btn-sm">Back to Members</a>
      </div>

      <div class="mb-6">
        <h1 class="text-2xl font-bold">Invite Members</h1>
        <p class="text-base-content/60">{@account.name}</p>
      </div>

      <%!-- Send Invitation section --%>
      <div class="mf-card p-6 mb-6" data-role="invite-form-section">
        <h2 class="text-lg font-semibold mb-4">Send an Invitation</h2>
        <p class="text-sm text-base-content/60 mb-4">
          The recipient will receive an email with a secure link. The link expires in 7 days and can only be used once.
        </p>

        <form
          id="invite_member_form"
          phx-submit="send_invitation"
          phx-change="validate"
        >
          <div class="form-control">
            <label class="label">
              <span class="label-text">Email address</span>
            </label>
            <input
              type="email"
              class="input w-full"
              name="invitation[email]"
              value={@invitation_form.params["email"] || ""}
              placeholder="colleague@example.com"
              phx-debounce="500"
            />
            <p :if={form_has_error?(@invitation_form, :email)} class="text-sm text-error mt-1">
              {form_first_error(@invitation_form, :email)}
            </p>
          </div>

          <div class="form-control mt-4">
            <label class="label">
              <span class="label-text">Access level</span>
            </label>
            <select class="select w-full" name="invitation[role]">
              <option
                value="read_only"
                selected={selected_role(@invitation_form, "read_only") || is_nil(@invitation_form.params["role"])}
              >
                Read Only
              </option>
              <option value="admin" selected={selected_role(@invitation_form, "admin")}>
                Admin
              </option>
              <option
                value="account_manager"
                selected={selected_role(@invitation_form, "account_manager")}
              >
                Account Manager
              </option>
            </select>
            <p :if={form_has_error?(@invitation_form, :role)} class="text-sm text-error mt-1">
              {form_first_error(@invitation_form, :role)}
            </p>
          </div>

          <div class="flex justify-end mt-6">
            <button type="submit" class="btn btn-primary w-full sm:w-auto" data-role="submit-invite">
              Send Invitation
            </button>
          </div>
        </form>
      </div>

      <%!-- Pending Invitations section --%>
      <div class="mf-card p-6" data-role="pending-invitations">
        <h2 class="text-lg font-semibold mb-4">Pending Invitations</h2>

        <div :if={@pending_invitations == []}>
          <p class="text-base-content/50 text-center py-4">No pending invitations.</p>
        </div>

        <div :if={@pending_invitations != []}>
          <div
            :for={invitation <- @pending_invitations}
            class="flex items-center justify-between gap-4 py-3 border-b border-base-300/30 last:border-0"
            data-role="pending-invitation-row"
            data-invitation-id={invitation.id}
          >
            <div>
              <div class="font-medium" data-role="invitation-email">{invitation.email}</div>
              <div class="mt-1">
                <span class={role_badge_class(invitation.role)}>
                  {role_label(invitation.role)}
                </span>
              </div>
              <div class="text-xs text-base-content/50 mt-1">
                Sent {format_relative(invitation.inserted_at)}
              </div>
              <div class="text-xs text-base-content/40">
                Expires {format_date(invitation.expires_at)}
              </div>
            </div>

            <div>
              <button
                class="btn btn-ghost btn-xs btn-error"
                phx-click="cancel_invitation"
                phx-value-id={invitation.id}
                data-role="cancel-invitation"
                data-email={invitation.email}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
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

    case Accounts.list_accounts(scope) do
      [] ->
        {:ok, redirect(socket, to: "/app/accounts")}

      [account | _] ->
        user_role = Accounts.get_user_role(scope, scope.user.id, account.id)
        mount_for_role(user_role, scope, account, socket)
    end
  end

  defp mount_for_role(role, scope, account, socket) when role in [:owner, :admin] do
    pending_invitations = Invitations.list_invitations(scope, account.id)
    invitation_changeset = Invitations.change_invitation(scope, %{})

    socket =
      socket
      |> assign(:page_title, "Invite Members")
      |> assign(:account, account)
      |> assign(:pending_invitations, pending_invitations)
      |> assign(:invitation_form, build_invitation_form(invitation_changeset, %{}, false))

    {:ok, socket}
  end

  defp mount_for_role(_role, _scope, _account, socket) do
    {:ok,
     socket
     |> put_flash(:error, "You do not have permission to invite members.")
     |> redirect(to: "/app/accounts/members")}
  end

  # ---------------------------------------------------------------------------
  # Handle params (no-op)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"invitation" => params}, socket) do
    scope = socket.assigns.current_scope
    changeset = Invitations.change_invitation(scope, params)

    {:noreply, assign(socket, :invitation_form, build_invitation_form(changeset, params, true))}
  end

  def handle_event("send_invitation", %{"invitation" => params}, socket) do
    scope = socket.assigns.current_scope
    account = socket.assigns.account
    email = Map.get(params, "email", "")

    case Invitations.send_invitation(scope, account.id, params) do
      {:ok, invitation} ->
        pending = [invitation | socket.assigns.pending_invitations]
        fresh_changeset = Invitations.change_invitation(scope, %{})

        {:noreply,
         socket
         |> assign(:pending_invitations, pending)
         |> assign(:invitation_form, build_invitation_form(fresh_changeset, %{}, false))
         |> put_flash(:info, "Invitation sent to #{email}.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You do not have permission to send invitations.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :invitation_form, build_invitation_form(changeset, params, true))}
    end
  end

  def handle_event("cancel_invitation", %{"id" => id_str}, socket) do
    scope = socket.assigns.current_scope
    invitation_id = String.to_integer(id_str)

    invitation = Enum.find(socket.assigns.pending_invitations, &(&1.id == invitation_id))

    case Invitations.cancel_invitation(scope, invitation_id) do
      {:ok, _} ->
        pending = Enum.reject(socket.assigns.pending_invitations, &(&1.id == invitation_id))

        {:noreply,
         socket
         |> assign(:pending_invitations, pending)
         |> put_flash(:info, "Invitation to #{invitation.email} cancelled.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not cancel invitation. Please try again.")}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_invitation_form(changeset, params, show_errors) do
    errors =
      if show_errors do
        Enum.map(changeset.errors, fn {field, {msg, opts}} ->
          {field, {translate_error(msg, opts), opts}}
        end)
      else
        []
      end

    %{params: params, errors: errors, changeset: changeset}
  end

  defp translate_error(msg, opts) do
    if count = opts[:count] do
      Gettext.dngettext(MetricFlowWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MetricFlowWeb.Gettext, "errors", msg, opts)
    end
  end

  defp form_has_error?(form, field) do
    form
    |> Map.get(:errors, [])
    |> Keyword.has_key?(field)
  end

  defp form_first_error(form, field) do
    case form |> Map.get(:errors, []) |> Keyword.get(field) do
      {msg, _opts} -> msg
      nil -> nil
    end
  end

  defp selected_role(form, role_value) do
    Map.get(form.params, "role") == role_value
  end

  defp role_badge_class(:admin), do: "badge badge-secondary"
  defp role_badge_class(:account_manager), do: "badge badge-accent"
  defp role_badge_class(:read_only), do: "badge badge-ghost"
  defp role_badge_class(:owner), do: "badge badge-primary"

  defp role_label(:admin), do: "Admin"
  defp role_label(:account_manager), do: "Account Manager"
  defp role_label(:read_only), do: "Read Only"
  defp role_label(:owner), do: "Owner"

  defp format_relative(nil), do: "unknown"

  defp format_relative(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)
    format_seconds(diff)
  end

  defp format_relative(%NaiveDateTime{} = dt) do
    dt
    |> DateTime.from_naive!("Etc/UTC")
    |> format_relative()
  end

  defp format_seconds(diff) when diff < 60, do: "just now"
  defp format_seconds(diff) when diff < 3600, do: "#{div(diff, 60)} minutes ago"
  defp format_seconds(diff) when diff < 86_400, do: "#{div(diff, 3600)} hours ago"
  defp format_seconds(diff), do: "#{div(diff, 86_400)} days ago"

  defp format_date(nil), do: "unknown"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
end
