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
    >
    <div class="mx-auto max-w-4xl">
      <.header>
        Subscription Plans
        <:subtitle>Manage plans for your agency customers</:subtitle>
      </.header>

      <div class="mt-8 space-y-6">
        <div :if={!@stripe_connected} class="alert alert-warning">
          <span>Connect your Stripe account before creating plans.</span>
          <.link navigate="/app/agency/stripe-connect" class="link link-primary">
            Connect Stripe
          </.link>
        </div>

        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-base">
              {if @editing_plan_id, do: "Edit Plan", else: "Create Plan"}
            </h2>
            <form
              id="plan-form"
              phx-submit={if @editing_plan_id, do: "update_plan", else: "create_plan"}
              phx-change="validate_plan"
              class="space-y-4"
            >
              <div class="form-control">
                <label class="label"><span class="label-text">Plan Name</span></label>
                <input
                  type="text"
                  name="plan[name]"
                  value={@form_params["name"]}
                  class={["input w-full", @form_errors[:name] && "input-error"]}
                  required
                  disabled={!@stripe_connected}
                />
                <p :if={@form_errors[:name]} class="text-sm text-error mt-1">
                  {@form_errors[:name]}
                </p>
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Monthly Price (cents)</span></label>
                <input
                  type="number"
                  name="plan[price_cents]"
                  value={@form_params["price_cents"]}
                  class={["input w-full", @form_errors[:price_cents] && "input-error"]}
                  required
                  min="1"
                  disabled={!@stripe_connected}
                />
                <p :if={@form_errors[:price_cents]} class="text-sm text-error mt-1">
                  {@form_errors[:price_cents]}
                </p>
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Billing Interval</span></label>
                <select name="plan[billing_interval]" class="select w-full" disabled={!@stripe_connected}>
                  <option value="monthly" selected={@form_params["billing_interval"] == "monthly"}>Monthly</option>
                  <option value="yearly" selected={@form_params["billing_interval"] == "yearly"}>Yearly</option>
                </select>
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Description</span></label>
                <textarea
                  name="plan[description]"
                  class="textarea w-full"
                  disabled={!@stripe_connected}
                >{@form_params["description"]}</textarea>
              </div>

              <div class="card-actions justify-end gap-2">
                <button :if={@editing_plan_id} type="button" phx-click="cancel_edit" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary" disabled={!@stripe_connected}>
                  {if @editing_plan_id, do: "Update Plan", else: "Create Plan"}
                </button>
              </div>
            </form>
          </div>
        </div>

        <div class="card bg-base-100 shadow">
          <div class="card-body p-0">
            <div :if={@plans == []} class="p-6 text-center text-base-content/60">
              No plans created yet
            </div>
            <div :if={@plans != []} class="overflow-x-auto">
              <table class="table w-full">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Price</th>
                    <th>Interval</th>
                    <th>Stripe Price ID</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={plan <- @plans} data-role="plan-row">
                    <td>{plan.name}</td>
                    <td>{format_price(plan.price_cents, plan.currency)}</td>
                    <td class="capitalize">{plan.billing_interval}</td>
                    <td class="font-mono text-xs">{plan.stripe_price_id || "—"}</td>
                    <td>
                      <span :if={plan.active} class="badge badge-success">Active</span>
                      <span :if={!plan.active} class="badge badge-ghost">Inactive</span>
                    </td>
                    <td class="space-x-2">
                      <button
                        :if={plan.active}
                        phx-click="edit_plan"
                        phx-value-id={plan.id}
                        data-role="edit-plan"
                        class="btn btn-xs btn-ghost"
                      >
                        Edit
                      </button>
                      <button
                        :if={plan.active}
                        phx-click="deactivate_plan"
                        phx-value-id={plan.id}
                        data-role="deactivate-plan"
                        data-confirm="Are you sure you want to deactivate this plan?"
                        class="btn btn-xs btn-ghost text-error"
                      >
                        Deactivate
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    account_id = socket.assigns.active_account_id

    plans = BillingRepository.list_plans(account_id)
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

  def handle_event("create_plan", %{"plan" => params}, socket) do
    account_id = socket.assigns.active_account_id
    params = Map.put(params, "agency_account_id", account_id)

    case BillingRepository.create_plan(params) do
      {:ok, _plan} ->
        plans = BillingRepository.list_plans(account_id)

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

    case plan |> Plan.changeset(params) |> MetricFlow.Repo.update() do
      {:ok, _plan} ->
        account_id = socket.assigns.active_account_id
        plans = BillingRepository.list_plans(account_id)

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
        plans = BillingRepository.list_plans(account_id)

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
    Map.new(errors, fn {field, {msg, _opts}} -> {field, msg} end)
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
