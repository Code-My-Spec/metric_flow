defmodule MetricFlowWeb.AccountTransferLive.Accept do
  @moduledoc """
  Confirm ownership transfer flow.

  Validates an ownership-transfer token from a URL parameter and allows the
  intended new owner to confirm it. Unauthenticated visitors must log in or
  register first — the token alone does not transfer ownership, confirming
  it as the matching authenticated user does.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.content flash={@flash} current_scope={@current_scope} active_account_name={assigns[:active_account_name]}>
      <div class="mf-content flex items-center justify-center min-h-[80vh]">
        <div class="mf-card p-8 w-full max-w-md">
          <h2 class="text-xl font-semibold text-center">Confirm Ownership Transfer</h2>

          <p class="text-sm text-base-content/70 text-center mt-2">
            <strong>{@transfer.initiated_by_email}</strong>
            {" wants to transfer ownership of "}
            <strong>{@transfer.account.name}</strong>
            {" to you."}
          </p>

          <div class="divider"></div>

          <div :if={@current_user}>
            <button
              class="btn btn-primary w-full"
              phx-click="accept"
              data-role="accept-transfer-btn"
            >
              Accept Ownership
            </button>
          </div>

          <div :if={is_nil(@current_user)}>
            <p class="text-sm text-base-content/60 text-center mb-4">
              Sign in or create an account to confirm this transfer.
            </p>
            <button
              class="btn btn-primary w-full"
              phx-click="log_in_to_confirm"
              data-role="log-in-to-confirm-btn"
            >
              Log In to Confirm
            </button>
            <button
              class="btn btn-ghost btn-sm w-full mt-2"
              phx-click="register_to_confirm"
              data-role="register-to-confirm-btn"
            >
              Create an Account
            </button>
          </div>
        </div>
      </div>
    </Layouts.content>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_ownership_transfer_by_token(token) do
      {:ok, transfer} ->
        current_user = current_user_from_scope(socket.assigns[:current_scope])

        socket =
          socket
          |> assign(:page_title, "Confirm Ownership Transfer")
          |> assign(:transfer, transfer)
          |> assign(:token, token)
          |> assign(:current_user, current_user)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "This transfer link is invalid or has already been used.")
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

    case Accounts.accept_ownership_transfer(scope, token) do
      {:ok, _transfer} ->
        {:noreply,
         socket
         |> put_flash(:info, "You are now the owner of this account.")
         |> redirect(to: "/app/accounts/settings")}

      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, "This transfer was not sent to your account.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "This transfer link is invalid or has already been used.")
         |> redirect(to: "/")}
    end
  end

  def handle_event("log_in_to_confirm", _params, socket) do
    token = socket.assigns.token
    return_to = URI.encode("/account_transfers/#{token}")

    {:noreply, redirect(socket, to: "/users/log-in?return_to=#{return_to}")}
  end

  def handle_event("register_to_confirm", _params, socket) do
    token = socket.assigns.token
    return_to = URI.encode("/account_transfers/#{token}")

    {:noreply, redirect(socket, to: "/users/register?return_to=#{return_to}")}
  end

  # Swoosh's test adapter delivers to the calling process; accepting sends
  # two completion emails synchronously before redirecting away.
  @impl true
  def handle_info({:email, %Swoosh.Email{}}, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp current_user_from_scope(nil), do: nil
  defp current_user_from_scope(%{user: user}), do: user
end
