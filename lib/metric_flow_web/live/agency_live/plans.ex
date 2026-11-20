defmodule MetricFlowWeb.AgencyLive.Plans do
  @moduledoc """
  Agency subscription plan management.

  Allows agency admins to create, edit, and deactivate custom subscription
  plans for their clients. Requires an active Stripe Connect account.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Billing.{BillingRepository, Plan}

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
      <main
        data-role="agency-plans-root"
        class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden"
      >
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Agency plans
          </p>
          <h1 class="text-2xl font-semibold text-base-content break-words">
            Price the subscriptions your clients can buy
          </h1>
          <p class="text-sm text-base-content/70 break-words">
            Fill the form to create a plan. Each saved plan shows below as a card with its price. Deactivating a plan stops new sign-ups; existing subscribers stay on it until they cancel.
          </p>
        </header>

        <div
          :if={!@stripe_connected}
          class="alert alert-warning rounded-box flex flex-wrap items-center gap-2"
        >
          <span class="break-words">Connect your Stripe account before creating plans.</span>
          <.link navigate="/app/agency/stripe-connect" class="link link-primary">
            Connect Stripe
          </.link>
        </div>

        <section
          data-role="plan-form-section"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <header class="space-y-1">
            <h2 class="text-lg font-semibold text-base-content">
              {if @editing_plan_id, do: "Edit Plan", else: "Create a new plan"}
            </h2>
            <p class="text-sm text-base-content/70">
              Give it a name, set a price in cents, and pick a billing interval; it syncs to Stripe when you save.
            </p>
          </header>

          <form
            id="plan-form"
            phx-submit={if @editing_plan_id, do: "update_plan", else: "create_plan"}
            phx-change="validate_plan"
            class="mt-4 space-y-4"
          >
            <div class="space-y-1">
              <label for="plan-name-input" class="block text-sm font-semibold text-base-content">
                Plan Name
              </label>
              <input
                id="plan-name-input"
                type="text"
                name="plan[name]"
                value={@form_params["name"]}
                class={[
                  "input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content",
                  @form_errors[:name] && "input-error"
                ]}
                required
              />
              <p :if={@form_errors[:name]} class="text-sm text-error">
                {@form_errors[:name]}
              </p>
            </div>

            <div class="space-y-1">
              <label
                for="plan-price-cents-input"
                class="block text-sm font-semibold text-base-content"
              >
                Price (cents)
              </label>
              <input
                id="plan-price-cents-input"
                type="number"
                name="plan[price_cents]"
                value={@form_params["price_cents"]}
                class={[
                  "input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content",
                  @form_errors[:price_cents] && "input-error"
                ]}
                required
                min="1"
              />
              <p :if={@form_errors[:price_cents]} class="text-sm text-error">
                {@form_errors[:price_cents]}
              </p>
            </div>

            <div class="space-y-1">
              <label
                for="plan-billing-interval"
                class="block text-sm font-semibold text-base-content"
              >
                Billing Interval
              </label>
              <select
                id="plan-billing-interval"
                name="plan[billing_interval]"
                class="select select-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
              >
                <option value="monthly" selected={@form_params["billing_interval"] == "monthly"}>
                  Monthly
                </option>
                <option value="yearly" selected={@form_params["billing_interval"] == "yearly"}>
                  Yearly
                </option>
              </select>
            </div>

            <div class="space-y-1">
              <label
                for="plan-description-input"
                class="block text-sm font-semibold text-base-content"
              >
                Description
              </label>
              <textarea
                id="plan-description-input"
                name="plan[description]"
                rows="3"
                class="textarea textarea-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
              >{@form_params["description"]}</textarea>
            </div>

            <div class="flex flex-wrap justify-end gap-2">
              <button
                :if={@editing_plan_id}
                type="button"
                phx-click="cancel_edit"
                class="rounded-box border border-neutral bg-base-200 px-4 py-2 text-sm text-base-content hover:bg-base-300"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
                disabled={!@editing_plan_id && !@stripe_connected}
              >
                {if @editing_plan_id, do: "Update Plan", else: "Create Plan"}
              </button>
            </div>
          </form>
        </section>

        <section data-role="plans-list" class="space-y-3">
          <div
            :if={@plans == []}
            class="rounded-box border border-neutral bg-base-200 p-6 text-center"
          >
            <p class="text-base font-semibold text-base-content">No plans created yet</p>
            <p class="mt-1 text-sm text-base-content/70">
              Create your first plan with the button above.
            </p>
          </div>

          <article
            :for={plan <- @plans}
            data-role="plan-row"
            class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0 space-y-1">
                <h2 class="text-lg font-semibold text-base-content break-words">
                  {plan.name}
                </h2>
                <p
                  :if={plan.description && plan.description != ""}
                  class="text-sm text-base-content/70 break-words"
                >
                  {plan.description}
                </p>
              </div>
              <div class="flex min-w-0 flex-col items-end gap-1">
                <span class="text-2xl font-semibold text-base-content whitespace-nowrap">
                  {format_price(plan.price_cents, plan.currency)}
                </span>
                <span class="text-xs text-base-content/60 capitalize">
                  per {plan.billing_interval}
                </span>
              </div>
            </div>

            <div class="mt-4 flex flex-wrap items-center justify-between gap-3">
              <div class="flex min-w-0 flex-wrap items-center gap-2">
                <span :if={plan.active} class="badge badge-success">Active</span>
                <span :if={!plan.active} class="badge badge-ghost">Inactive</span>
                <span class="text-xs text-base-content/60">Stripe Price ID:</span>
                <span class="font-mono text-xs text-base-content/60 break-all">
                  {plan.stripe_price_id || "—"}
                </span>
              </div>
              <div class="flex flex-wrap items-center gap-2">
                <button
                  :if={plan.active}
                  phx-click="edit_plan"
                  phx-value-id={plan.id}
                  data-role="edit-plan"
                  class="rounded-box border border-neutral bg-base-200 px-3 py-1 text-xs text-base-content hover:bg-base-300"
                >
                  Edit
                </button>
                <button
                  :if={plan.active}
                  phx-click="deactivate_plan"
                  phx-value-id={plan.id}
                  data-role="deactivate-plan"
                  data-confirm="Are you sure you want to deactivate this plan?"
                  class="rounded-box border border-error bg-base-200 px-3 py-1 text-xs font-semibold text-error hover:bg-base-300"
                >
                  Deactivate
                </button>
              </div>
            </div>
          </article>
        </section>
      </main>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    account_id = socket.assigns.active_account_id

    plans = BillingRepository.list_all_plans(account_id)
    stripe_account = BillingRepository.get_stripe_account_by_agency(account_id)
    stripe_connected = stripe_account != nil && stripe_account.onboarding_status == :complete

    socket =
      socket
      |> assign(:plans, plans)
      |> assign(:stripe_connected, stripe_connected)
      |> assign(:editing_plan_id, nil)
      |> assign(:form_params, %{})
      |> assign(:form_errors, %{})

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_plan", %{"plan" => params}, socket) do
    changeset =
      %Plan{}
      |> Plan.changeset(params)
      |> Map.put(:action, :validate)

    errors = extract_errors(changeset)
    {:noreply, assign(socket, form_params: params, form_errors: errors)}
  end

  def handle_event("create_plan", _params, socket) when not socket.assigns.stripe_connected do
    {:noreply, socket}
  end

  def handle_event("create_plan", %{"plan" => params}, socket) do
    account_id = socket.assigns.active_account_id
    params = Map.put(params, "agency_account_id", account_id)

    case MetricFlow.Billing.create_plan(params) do
      {:ok, _plan} ->
        plans = BillingRepository.list_all_plans(account_id)

        socket =
          socket
          |> assign(plans: plans, form_params: %{}, form_errors: %{})
          |> put_flash(:info, "Plan created")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form_errors: extract_errors(changeset))}
    end
  end

  def handle_event("edit_plan", %{"id" => id}, socket) do
    plan = BillingRepository.get_plan(String.to_integer(id))

    params = %{
      "name" => plan.name,
      "price_cents" => to_string(plan.price_cents),
      "billing_interval" => to_string(plan.billing_interval),
      "description" => plan.description || ""
    }

    socket =
      socket
      |> assign(editing_plan_id: plan.id, form_params: params, form_errors: %{})

    {:noreply, socket}
  end

  def handle_event("update_plan", %{"plan" => params}, socket) do
    plan = BillingRepository.get_plan(socket.assigns.editing_plan_id)

    case MetricFlow.Billing.update_plan(plan, params) do
      {:ok, _plan} ->
        account_id = socket.assigns.active_account_id
        plans = BillingRepository.list_all_plans(account_id)

        socket =
          socket
          |> assign(plans: plans, editing_plan_id: nil, form_params: %{}, form_errors: %{})
          |> put_flash(:info, "Plan updated")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form_errors: extract_errors(changeset))}
    end
  end

  def handle_event("deactivate_plan", %{"id" => id}, socket) do
    plan = BillingRepository.get_plan(String.to_integer(id))

    case plan |> Plan.changeset(%{active: false}) |> MetricFlow.Repo.update() do
      {:ok, _plan} ->
        account_id = socket.assigns.active_account_id
        plans = BillingRepository.list_all_plans(account_id)

        socket =
          socket
          |> assign(:plans, plans)
          |> put_flash(:info, "Plan deactivated")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to deactivate plan")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_plan_id: nil, form_params: %{}, form_errors: %{})}
  end

  defp extract_errors(%Ecto.Changeset{errors: errors}) do
    Map.new(errors, fn {field, {msg, opts}} -> {field, translate_error_msg({msg, opts})} end)
  end

  defp extract_errors(reason) when is_binary(reason) or is_atom(reason) do
    %{base: "could not create the plan: #{reason}"}
  end

  defp translate_error_msg({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(MetricFlowWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MetricFlowWeb.Gettext, "errors", msg, opts)
    end
  end

  defp format_price(cents, currency) do
    dollars = cents / 100
    symbol = currency_symbol(currency)
    "#{symbol}#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end

  defp currency_symbol("usd"), do: "$"
  defp currency_symbol("eur"), do: "€"
  defp currency_symbol("gbp"), do: "£"
  defp currency_symbol(_), do: "$"
end
