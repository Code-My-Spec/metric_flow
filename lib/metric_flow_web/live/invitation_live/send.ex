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
      active_account_type={assigns[:active_account_type]}
    >
      <div class="mx-auto max-w-3xl space-y-6 overflow-x-hidden">
        <header class="space-y-1">
          <h1 class="text-2xl font-semibold text-base-content break-words">Invite Members</h1>
          <p class="text-sm text-base-content/70 break-words">{@account.name}</p>
          <a
            href="/app/accounts/members"
            class="inline-block text-sm text-primary hover:underline"
          >
            Back to Members
          </a>
        </header>

        <%!-- Send Invitation section --%>
        <section
          aria-labelledby="send-invitation-heading"
          data-role="invite-form-section"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <header class="space-y-1">
            <h2
              id="send-invitation-heading"
              class="text-lg font-semibold text-base-content"
            >
              Send an Invitation
            </h2>
            <p class="text-sm text-base-content/70 break-words">
              The recipient receives an email with a secure link. The link expires in 7 days and can only be used once.
            </p>
          </header>

          <form
            id="invite_member_form"
            phx-submit="send_invitation"
            phx-change="validate"
            class="mt-4 space-y-4"
          >
            <div class="space-y-1">
              <label
                for="invitation_email"
                class="block text-sm font-semibold text-base-content"
              >
                Email address
              </label>
              <input
                id="invitation_email"
                type="email"
                name="invitation[email]"
                class="input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
                value={@invitation_form.params["email"] || ""}
                placeholder="colleague@example.com"
                phx-debounce="500"
              />
              <p :if={form_has_error?(@invitation_form, :email)} class="text-sm text-error">
                {form_first_error(@invitation_form, :email)}
              </p>
            </div>

            <div class="space-y-1">
              <label
                for="invitation_role"
                class="block text-sm font-semibold text-base-content"
              >
                Access level
              </label>
              <select
                id="invitation_role"
                name="invitation[role]"
                class="select select-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
              >
                <option
                  :for={role <- invite_roles(@current_user_role)}
                  value={role}
                  selected={
                    selected_role(@invitation_form, role) ||
                      (role == "read_only" and is_nil(@invitation_form.params["role"]))
                  }
                >
                  {role_label(String.to_existing_atom(role))}
                </option>
              </select>
              <p :if={form_has_error?(@invitation_form, :role)} class="text-sm text-error">
                {form_first_error(@invitation_form, :role)}
              </p>
            </div>

            <button
              type="submit"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
              data-role="submit-invite"
            >
              Send Invitation
            </button>
          </form>
        </section>

        <%!-- Pending Invitations section --%>
        <section
          aria-labelledby="pending-invitations-heading"
          data-role="pending-invitations"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <header class="space-y-1">
            <h2
              id="pending-invitations-heading"
              class="text-lg font-semibold text-base-content"
            >
              Pending Invitations
            </h2>
            <p class="text-sm text-base-content/70">
              Links that have been sent and are still awaiting a response.
            </p>
          </header>

          <div :if={@pending_invitations == []} class="mt-4 text-sm text-base-content/70">
            No pending invitations.
          </div>

          <ul :if={@pending_invitations != []} class="mt-4 divide-y divide-neutral">
            <li
              :for={invitation <- @pending_invitations}
              class="flex flex-wrap items-start justify-between gap-3 py-3 first:pt-0 last:pb-0"
              data-role="pending-invitation-row"
              data-invitation-id={invitation.id}
            >
              <div class="min-w-0 flex-1 space-y-1">
                <div
                  class="text-sm font-medium text-base-content break-all"
                  data-role="invitation-email"
                >
                  {invitation.email}
                </div>
                <div>
                  <span class={role_badge_class(invitation.role)}>
                    {role_label(invitation.role)}
                  </span>
                </div>
                <div class="text-xs text-base-content/60 break-words">
                  Sent {format_relative(invitation.inserted_at)} · Expires {format_date(
                    invitation.expires_at
                  )}
                </div>
              </div>

              <button
                type="button"
                class="rounded-box border border-error bg-base-200 px-3 py-1 text-xs font-semibold text-error hover:bg-base-300"
                phx-click="cancel_invitation"
                phx-value-id={invitation.id}
                data-role="cancel-invitation"
                data-email={invitation.email}
              >
                Cancel
              </button>
            </li>
          </ul>
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
      |> assign(:current_user_role, role)
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
        {:noreply,
         assign(socket, :invitation_form, build_invitation_form(changeset, params, true))}
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

  # Owners may invite at any role. Admins may only invite at account_manager
  # and below — matches Authorization.target_role_allowed?/2, which the
  # backend also enforces via Accounts.can_assign_role?/3.
  defp invite_roles(:owner), do: ~w(read_only account_manager admin owner)
  defp invite_roles(_role), do: ~w(read_only account_manager)

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
