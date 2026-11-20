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
    <Layouts.content
      flash={@flash}
      current_scope={@current_scope}
      active_account_name={assigns[:active_account_name]}
    >
      <div class="mx-auto w-full max-w-md overflow-x-hidden">
        <section
          aria-labelledby="transfer-heading"
          class="rounded-box border border-neutral bg-base-200 p-6 sm:p-8"
        >
          <div class="flex items-start gap-4">
            <div class="avatar placeholder shrink-0">
              <div class="h-12 w-12 rounded-full bg-primary text-primary-content">
                <span class="text-lg font-semibold">
                  {String.upcase(String.first(@transfer.account.name))}
                </span>
              </div>
            </div>
            <div class="min-w-0 flex-1 space-y-1">
              <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                Ownership transfer
              </p>
              <h1
                id="transfer-heading"
                class="text-xl font-semibold text-base-content break-words"
              >
                Become the owner of {@transfer.account.name}
              </h1>
            </div>
          </div>

          <p class="mt-4 text-sm text-base-content/80 break-words">
            <strong class="break-all text-base-content">{@transfer.initiated_by_email}</strong>
            is handing ownership of
            <strong class="text-base-content">{@transfer.account.name}</strong>
            to you.
          </p>

          <ul class="mt-4 space-y-2 text-sm text-base-content/80">
            <li class="flex gap-2">
              <span aria-hidden="true" class="text-primary">&bull;</span>
              <span>You become the sole owner and control who has access.</span>
            </li>
            <li class="flex gap-2">
              <span aria-hidden="true" class="text-primary">&bull;</span>
              <span>
                {@transfer.initiated_by_email} keeps access as
                <strong class="text-base-content">{previous_owner_role_label(@transfer)}</strong>
                and can no longer transfer or delete the account.
              </span>
            </li>
            <li class="flex gap-2">
              <span aria-hidden="true" class="text-primary">&bull;</span>
              <span>Connected data, dashboards and history stay with the account.</span>
            </li>
          </ul>

          <div :if={@current_user} class="mt-6 space-y-3">
            <button
              type="button"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
              phx-click="accept"
              data-role="accept-transfer-btn"
            >
              Accept ownership of {@transfer.account.name}
            </button>
            <p class="text-xs text-base-content/60">
              Signed in as <strong class="break-all text-base-content">{@current_user.email}</strong>.
            </p>
          </div>

          <div :if={is_nil(@current_user)} class="mt-6 space-y-3">
            <p class="text-sm text-base-content/70">
              Sign in or create an account to confirm this transfer.
            </p>
            <button
              type="button"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
              phx-click="log_in_to_confirm"
              data-role="log-in-to-confirm-btn"
            >
              Log In to Confirm
            </button>
            <button
              type="button"
              class="w-full rounded-box border border-neutral bg-base-200 px-4 py-2 text-sm font-semibold text-base-content hover:bg-base-300"
              phx-click="register_to_confirm"
              data-role="register-to-confirm-btn"
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

  defp previous_owner_role_label(%{remain_admin: true}), do: "Admin"
  defp previous_owner_role_label(_transfer), do: "Account Manager"
end
