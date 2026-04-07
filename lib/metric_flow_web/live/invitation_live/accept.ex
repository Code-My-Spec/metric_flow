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
    <Layouts.app flash={@flash} current_scope={@current_scope} active_account_name={assigns[:active_account_name]}>
      <div class="mf-content flex items-center justify-center min-h-[80vh]">
        <div class="mf-card p-8 w-full max-w-md">
          <div class="flex flex-col items-center">
            <div class="avatar placeholder mb-4">
              <div class="bg-primary text-primary-content rounded-full w-14 h-14">
                <span class="text-xl font-bold">
                  {String.upcase(String.first(@invitation.account.name))}
                </span>
              </div>
            </div>

            <h2 class="text-xl font-semibold text-center">You've been invited</h2>

            <p class="text-sm text-base-content/70 text-center mt-2">
              <strong>{@invitation.invited_by.email}</strong>
              {" has invited you to join "}
              <strong>{@invitation.account.name}</strong>
              {" as a "}
              <strong>{role_label(@invitation.role)}</strong>.
            </p>
          </div>

          <div class="divider"></div>

          <div :if={@current_user}>
            <button
              class="btn btn-primary w-full"
              phx-click="accept"
              data-role="accept-btn"
            >
              Accept Invitation
            </button>
            <button
              class="btn btn-ghost btn-sm w-full mt-2"
              phx-click="decline"
              data-role="decline-btn"
            >
              Decline
            </button>
          </div>

          <div :if={is_nil(@current_user)}>
            <p class="text-sm text-base-content/60 text-center mb-4">
              Sign in or create an account to accept this invitation.
            </p>
            <button
              class="btn btn-primary w-full"
              phx-click="log_in_to_accept"
              data-role="log-in-btn"
            >
              Log In to Accept
            </button>
            <button
              class="btn btn-ghost btn-sm w-full mt-2"
              phx-click="register_to_accept"
              data-role="register-btn"
            >
              Create an Account
            </button>
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
