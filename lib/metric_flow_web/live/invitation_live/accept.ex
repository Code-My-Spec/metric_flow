defmodule MetricFlowWeb.InvitationLive.Accept do
  @moduledoc """
  Accept invitation flow.

  Validates an invitation token from a URL parameter and allows the recipient
  to accept or decline access to an account. Handles both authenticated users
  (who accept directly) and unauthenticated users (who are redirected to log in
  or register before being returned to this page).
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Invitations

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.content
      flash={@flash}
      current_scope={@current_scope}
      active_account_name={assigns[:active_account_name]}
    >
      <div class="mx-auto w-full max-w-md overflow-x-hidden">
        <section
          aria-labelledby="invitation-heading"
          class="rounded-box border border-neutral bg-base-200 p-6 sm:p-8"
        >
          <div class="flex items-start gap-4">
            <div class="avatar placeholder shrink-0">
              <div class="h-12 w-12 rounded-full bg-primary text-primary-content">
                <span class="text-lg font-semibold">
                  {String.upcase(String.first(@invitation.account.name))}
                </span>
              </div>
            </div>
            <div class="min-w-0 flex-1 space-y-1">
              <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                You've been invited
              </p>
              <h1
                id="invitation-heading"
                class="text-xl font-semibold text-base-content break-words"
              >
                Join {@invitation.account.name}
              </h1>
            </div>
          </div>

          <p class="mt-4 text-sm text-base-content/80 break-words">
            <strong class="break-all text-base-content">{@invitation.invited_by.email}</strong>
            invited you as <strong class="text-base-content">{role_label(@invitation.role)}</strong>.
          </p>

          <div :if={@current_user} class="mt-6 space-y-3">
            <button
              type="button"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
              phx-click="accept"
              data-role="accept-btn"
            >
              Accept Invitation
            </button>
            <button
              type="button"
              class="w-full rounded-box px-4 py-2 text-sm text-base-content/60 hover:text-base-content"
              phx-click="decline"
              data-role="decline-btn"
            >
              Decline
            </button>
          </div>

          <div :if={is_nil(@current_user)} class="mt-6 space-y-3">
            <p class="text-sm text-base-content/70">
              Sign in or create an account to accept this invitation.
            </p>
            <button
              type="button"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
              phx-click="log_in_to_accept"
              data-role="log-in-btn"
            >
              Log In to Accept
            </button>
            <button
              type="button"
              class="w-full rounded-box border border-neutral bg-base-200 px-4 py-2 text-sm font-semibold text-base-content hover:bg-base-300"
              phx-click="register_to_accept"
              data-role="register-btn"
            >
              Create an Account
            </button>
          </div>
        </section>
      </div>
    </Layouts.content>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Invitations.get_invitation_by_token(token) do
      {:ok, invitation} ->
        current_user = current_user_from_scope(socket.assigns[:current_scope])

        socket =
          socket
          |> assign(:page_title, "Accept Invitation")
          |> assign(:invitation, invitation)
          |> assign(:token, token)
          |> assign(:current_user, current_user)

        {:ok, socket}

      {:error, :expired} ->
        {:ok,
         socket
         |> put_flash(:error, "This invitation has expired.")
         |> redirect(to: "/")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "This invitation link is invalid or has already been used.")
         |> redirect(to: "/")}
    end
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
  def handle_event("accept", _params, socket) do
    scope = socket.assigns.current_scope
    token = socket.assigns.token
    account_name = socket.assigns.invitation.account.name

    case Invitations.accept_invitation(scope, token) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "You now have access to #{account_name}.")
         |> redirect(to: "/app/accounts")}

      {:error, :already_member} ->
        {:noreply,
         socket
         |> put_flash(:info, "You already have access to this account.")
         |> redirect(to: "/app/accounts")}

      {:error, :expired} ->
        {:noreply,
         socket
         |> put_flash(:error, "This invitation has expired.")
         |> redirect(to: "/")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "This invitation is no longer valid.")
         |> redirect(to: "/")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Something went wrong. Please try again.")}
    end
  end

  def handle_event("decline", _params, socket) do
    scope = socket.assigns.current_scope
    token = socket.assigns.token

    case Invitations.decline_invitation(scope, token) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation declined.")
         |> redirect(to: "/")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Something went wrong.")}
    end
  end

  def handle_event("log_in_to_accept", _params, socket) do
    token = socket.assigns.token
    return_to = URI.encode("/invitations/#{token}")

    {:noreply, redirect(socket, to: "/users/log-in?return_to=#{return_to}")}
  end

  def handle_event("register_to_accept", _params, socket) do
    token = socket.assigns.token
    return_to = URI.encode("/invitations/#{token}")

    {:noreply, redirect(socket, to: "/users/register?return_to=#{return_to}")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp current_user_from_scope(nil), do: nil
  defp current_user_from_scope(%{user: user}), do: user

  defp role_label(:owner), do: "Owner"
  defp role_label(:admin), do: "Admin"
  defp role_label(:account_manager), do: "Account Manager"
  defp role_label(:read_only), do: "Read Only"

  defp role_label(role) when is_atom(role),
    do: role |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
end
