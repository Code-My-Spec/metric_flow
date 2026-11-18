defmodule MetricFlowWeb.OnboardingLive.Connect do
  @moduledoc """
  Data-source setup wizard: Connect Google → pick what to sync → Connect
  YouTube → pick channels → Connect Meta → pick → Connect QuickBooks → pick
  → Done.

  One step per connection (one OAuth grant each). Google is a single
  sign-in covering Analytics, Ads, Search Console and Business Profile; the
  step then lists each product with its own inline picker. YouTube has its
  own sign-in. Every step can be skipped, and the wizard resumes at the
  first unfinished connection.

  All data and actions go through `MetricFlow.Onboarding`.

  Route: GET /app/onboarding/connect[?step=google|youtube|facebook_ads|quickbooks|done]
  """

  use MetricFlowWeb, :live_view

  import MetricFlowWeb.SetupComponents, only: [status_badge: 1]

  alias MetricFlow.Accounts
  alias MetricFlow.Onboarding

  @steps [:google, :youtube, :facebook_ads, :quickbooks, :done]
  @search_threshold 6
  @synced_note "Syncing — first data usually appears within a few minutes; full history can take up to an hour."

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :current, current_connection(assigns))

    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
      active_account_type={assigns[:active_account_type]}
    >
      <div class="mx-auto max-w-3xl px-4 py-8" data-role="setup-wizard">
        <div class="mb-8">
          <h1 class="text-2xl font-bold">Set up your data sources</h1>
          <p class="mt-1 text-base-content/60">
            Connect each platform once, pick what to sync, and you're done. You can skip anything and come back later.
          </p>
        </div>

        <ol id="wizard-stepper" class="mb-8 flex items-center gap-2 text-sm">
          <li
            :for={{step, idx} <- Enum.with_index(@steps)}
            id={"wizard-step-#{step}"}
            data-current={to_string(step == @step)}
            data-done={to_string(step_done?(step, @status))}
            class="flex flex-1 items-center gap-2"
          >
            <.link
              patch={~p"/app/onboarding/connect?step=#{step}"}
              class={[
                "flex items-center gap-2 rounded-full px-3 py-1.5 transition-colors",
                step == @step && "bg-primary text-primary-content font-semibold",
                step != @step && "hover:bg-base-200"
              ]}
            >
              <span class={[
                "flex size-6 items-center justify-center rounded-full text-xs",
                step_done?(step, @status) && "bg-success text-success-content",
                !step_done?(step, @status) && step != @step && "bg-base-200",
                !step_done?(step, @status) && step == @step && "bg-primary-content/20"
              ]}>
                <%= if step_done?(step, @status) do %>
                  <.icon name="hero-check-mini" class="size-4" />
                <% else %>
                  {idx + 1}
                <% end %>
              </span>
              <span class={[step != @step && "hidden sm:inline"]}>{step_label(step)}</span>
            </.link>
            <span :if={step != :done} class="h-px flex-1 bg-base-content/15"></span>
          </li>
        </ol>

        <%= if @step == :done do %>
          {render_done(assigns)}
        <% else %>
          {render_connection(assigns)}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_connection(assigns) do
    ~H"""
    <section id={"connection-#{@current.key}"} class="mf-card p-6">
      <div class="mb-6">
        <h2 class="text-xl font-semibold">{connection_title(@current)}</h2>
        <p class="mt-1 text-sm text-base-content/60">{@current.description}</p>
      </div>

      <%= if @current.state == :not_connected do %>
        <div id={"not-connected-#{@current.key}"}>
          <p class="mb-3 text-sm font-medium">What you'll get</p>
          <ul class="mb-6 space-y-3">
            <li :for={product <- @current.products} class="flex gap-3">
              <.icon name="hero-chart-bar" class="mt-0.5 size-5 shrink-0 text-primary" />
              <div>
                <p class="font-medium">{product.name}</p>
                <p class="text-sm text-base-content/60">{product.gives}</p>
              </div>
            </li>
          </ul>

          <p :if={@current.key == :google} class="mb-4 text-sm text-base-content/60">
            Google will ask you to tick each product — leave them all ticked to set everything up at once.
          </p>
          <p :if={@current.key == :youtube} class="mb-4 text-sm text-base-content/60">
            You'll pick which channels to sync right after signing in with Google.
          </p>
          <p :if={@current.key == :quickbooks} class="mb-4 text-sm text-base-content/60">
            You'll pick your company on Intuit's screen. You need to be a QuickBooks admin.
          </p>

          <a
            :if={@can_modify}
            id={"connect-#{@current.key}"}
            href={Onboarding.connect_path(@current.key, return_path(@current.key))}
            class="btn btn-primary btn-lg w-full sm:w-auto"
          >
            Connect {@current.name}
          </a>
          <p :if={!@can_modify} class="text-sm text-warning">
            Ask an account owner or admin to connect {@current.name}.
          </p>
        </div>
      <% else %>
        <div class="space-y-4">
          <.product_row
            :for={product <- @current.products}
            product={product}
            picker={@pickers[product.key]}
            can_modify={@can_modify}
            connection={@current.key}
          />
        </div>
      <% end %>

      <div class="mt-8 flex items-center justify-between border-t border-base-content/10 pt-6">
        <.link
          :if={prev_step(@step)}
          patch={~p"/app/onboarding/connect?step=#{prev_step(@step)}"}
          class="btn btn-ghost btn-sm"
        >
          Back
        </.link>
        <span :if={!prev_step(@step)}></span>
        <.link
          id="wizard-continue"
          patch={~p"/app/onboarding/connect?step=#{next_step(@step)}"}
          class={[
            "btn",
            any_product_ready?(@current) && "btn-primary",
            !any_product_ready?(@current) && "btn-ghost"
          ]}
        >
          {if any_product_ready?(@current), do: "Continue", else: "Skip for now"}
        </.link>
      </div>
    </section>
    """
  end

  attr :product, :map, required: true
  attr :picker, :map, default: nil
  attr :can_modify, :boolean, default: false
  attr :connection, :atom, required: true

  defp product_row(assigns) do
    ~H"""
    <div
      id={"product-#{@product.key}"}
      data-status={@product.status}
      class="rounded-lg border border-base-content/10 p-4"
    >
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="font-medium">{@product.name}</p>
          <p class="text-sm text-base-content/60">{@product.gives}</p>
          <p :if={@product.connected_as} class="mt-1 text-xs text-base-content/50">
            Connected as {@product.connected_as}
          </p>
        </div>
        <.status_badge status={@product.status} />
      </div>

      <%= case @product.status do %>
        <% :not_granted -> %>
          <div class="mt-3 flex items-center justify-between gap-4 text-sm">
            <span class="text-base-content/60">
              Access not granted — this box was unticked on Google's screen.
            </span>
            <a
              :if={@can_modify}
              id={"grant-#{@product.key}"}
              href={Onboarding.connect_path(@connection, return_path(@connection))}
              class="btn btn-outline btn-xs"
            >
              Grant access
            </a>
          </div>
        <% :reconnect -> %>
          <div class="mt-3 flex items-center justify-between gap-4 text-sm">
            <span class="text-warning">The connection expired.</span>
            <a
              :if={@can_modify}
              id={"reconnect-#{@product.key}"}
              href={Onboarding.connect_path(@connection, return_path(@connection))}
              class="btn btn-warning btn-xs"
            >
              Reconnect
            </a>
          </div>
        <% :not_connected -> %>
        <% _ -> %>
          <.picker
            :if={@picker}
            product={@product}
            picker={@picker}
            can_modify={@can_modify}
            connection={@connection}
          />
      <% end %>
    </div>
    """
  end

  attr :product, :map, required: true
  attr :picker, :map, required: true
  attr :can_modify, :boolean, default: false
  attr :connection, :atom, required: true

  defp picker(assigns) do
    assigns =
      assign(assigns,
        multi?: assigns.product.mode == :multi,
        show_search?: length(assigns.picker.options) > @search_threshold
      )

    ~H"""
    <div class="mt-4">
      <%= case @picker.state do %>
        <% :loading -> %>
          <div id={"options-loading-#{@product.key}"} class="space-y-2" aria-busy="true">
            <div class="h-9 animate-pulse rounded bg-base-200"></div>
            <div class="h-9 animate-pulse rounded bg-base-200"></div>
          </div>
        <% :error -> %>
          <div class="flex flex-wrap items-center justify-between gap-2">
            <p id={"options-error-#{@product.key}"} class="text-sm text-error">{@picker.error}</p>
            <a
              :if={@picker.reconnect? and @can_modify}
              id={"reconnect-#{@product.key}"}
              href={Onboarding.connect_path(@connection, return_path(@connection))}
              class="btn btn-outline btn-xs"
            >
              Reconnect
            </a>
          </div>
        <% :loaded when @picker.options == [] -> %>
          <p
            :if={@product.key == :youtube}
            id={"options-empty-#{@product.key}"}
            class="text-sm text-base-content/60"
          >
            No channel on this Google account.
          </p>
          <p
            :if={@product.key != :youtube}
            id={"options-empty-#{@product.key}"}
            class="text-sm text-base-content/60"
          >
            No {plural(@product.noun)} found{if @product.connected_as,
              do: " for #{@product.connected_as}"}.
            Make sure this login has access to the {@product.noun} you want, then reload this page.
          </p>
        <% :loaded -> %>
          <.form
            for={%{}}
            id={"picker-#{@product.key}"}
            phx-change="change"
            phx-submit="save"
          >
            <input type="hidden" name="product" value={@product.key} />
            <div :if={@show_search? or @multi?} class="mb-2 flex items-center gap-2">
              <input
                :if={@show_search?}
                type="search"
                name="q"
                value={@picker.query}
                placeholder={"Search #{plural(@product.noun)}"}
                phx-debounce="150"
                class="input input-sm input-bordered flex-1"
              />
              <button
                :if={@multi?}
                type="button"
                phx-click="select_all"
                phx-value-product={@product.key}
                class="btn btn-ghost btn-xs"
              >
                Select all
              </button>
            </div>
            <div class="max-h-64 space-y-1 overflow-y-auto">
              <label
                :for={option <- @picker.options}
                class={[
                  "flex cursor-pointer items-center gap-3 rounded px-2 py-1.5 hover:bg-base-200",
                  !matches?(option, @picker.query) && "hidden"
                ]}
              >
                <input
                  type={if @multi?, do: "checkbox", else: "radio"}
                  name="ids[]"
                  value={option.id}
                  checked={MapSet.member?(@picker.selected, to_string(option.id))}
                  class={if @multi?, do: "checkbox checkbox-sm", else: "radio radio-sm"}
                />
                <span class="text-sm">{option.name}</span>
                <span class="ml-auto truncate text-xs text-base-content/40">{option.id}</span>
              </label>
            </div>
            <p :if={@picker.error} class="mt-2 text-sm text-error">{@picker.error}</p>
            <p :if={@picker.note} id={"synced-note-#{@product.key}"} class="mt-2 text-sm text-success">
              {@picker.note}
            </p>
            <div class="mt-3 flex justify-end">
              <button
                id={"save-selection-#{@product.key}"}
                type="submit"
                disabled={!@can_modify or MapSet.size(@picker.selected) == 0}
                class="btn btn-primary btn-sm"
              >
                {if @product.status == :ready, do: "Update", else: "Save & sync"}
              </button>
            </div>
          </.form>
      <% end %>
    </div>
    """
  end

  # A provider 401 while listing options means the saved sign-in was
  # rejected — not the role check `explain_error(:unauthorized)` describes.
  defp options_error(key, :unauthorized) do
    noun = Onboarding.product_info(key).noun
    "The saved sign-in was rejected. Reconnect to load your #{plural(noun)}."
  end

  defp options_error(_key, reason), do: Onboarding.explain_error(reason)

  defp plural("property"), do: "properties"
  defp plural(noun), do: noun <> "s"

  defp matches?(_option, q) when q in [nil, ""], do: true

  defp matches?(option, q) do
    q = String.downcase(q)

    String.contains?(String.downcase(to_string(option.name)), q) or
      String.contains?(String.downcase(to_string(option.id)), q)
  end

  defp render_done(assigns) do
    ~H"""
    <section id="wizard-done" class="mf-card p-6">
      <h2 class="text-xl font-semibold">
        {if Enum.any?(@status, &any_product_ready?/1),
          do: "You're all set",
          else: "Nothing connected yet"}
      </h2>
      <p class="mt-1 text-sm text-base-content/60">
        {if Enum.any?(@status, &any_product_ready?/1),
          do: "Your data is syncing. Dashboards fill in as it arrives.",
          else: "Connect at least one data source to see your metrics."}
      </p>

      <ul class="mt-6 space-y-3">
        <li
          :for={conn <- @status}
          id={"done-summary-#{conn.key}"}
          class="flex items-start justify-between gap-4 rounded-lg border border-base-content/10 p-4"
        >
          <div>
            <p class="font-medium">{conn.name}</p>
            <p class="text-sm text-base-content/60">
              <%= case ready_products(conn) do %>
                <% [] -> %>
                  Not set up
                <% ready -> %>
                  {Enum.map_join(ready, ", ", & &1.name)}
              <% end %>
            </p>
          </div>
          <.link
            :if={ready_products(conn) == []}
            patch={~p"/app/onboarding/connect?step=#{conn.key}"}
            class="btn btn-ghost btn-xs"
          >
            Set up
          </.link>
          <.icon
            :if={ready_products(conn) != []}
            name="hero-check-circle"
            class="size-6 text-success"
          />
        </li>
      </ul>

      <div class="mt-8 flex flex-col gap-3 sm:flex-row">
        <.link id="open-dashboard" navigate={~p"/app/dashboard"} class="btn btn-primary">
          Open your dashboard
        </.link>
        <.link id="manage-connections" navigate={~p"/app/integrations"} class="btn btn-ghost">
          Manage connections
        </.link>
      </div>
    </section>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount / params
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope =
      MetricFlow.Users.Scope.put_account_id(
        socket.assigns.current_scope,
        socket.assigns[:active_account_id]
      )

    role =
      if socket.assigns[:active_account_id] do
        Accounts.get_user_role(scope, scope.user.id, socket.assigns.active_account_id)
      end

    {:ok,
     socket
     |> assign(:current_scope, scope)
     |> assign(:page_title, "Set up data sources")
     |> assign(:steps, @steps)
     # Integrations belong to the user, so a user with no account yet (fresh
     # sign-up) sets up their own; inside an account, read-only members can't.
     |> assign(:can_modify, is_nil(role) or role in [:owner, :admin, :account_manager])
     |> assign(:pickers, %{})
     |> assign(:status, Onboarding.status(scope))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    step = parse_step(params["step"]) || resume_step(socket.assigns.status)

    socket =
      socket
      |> assign(:step, step)
      |> load_pickers()

    {:noreply, socket}
  end

  defp parse_step(nil), do: nil

  defp parse_step(str) do
    Enum.find(@steps, &(Atom.to_string(&1) == str))
  end

  defp resume_step(status) do
    case Enum.find(status, &(&1.state != :done)) do
      nil -> :done
      conn -> conn.key
    end
  end

  # Starts an options fetch for every pickable product on the current step
  # that hasn't been loaded yet.
  defp load_pickers(%{assigns: %{step: :done}} = socket), do: socket

  defp load_pickers(socket) do
    conn = Enum.find(socket.assigns.status, &(&1.key == socket.assigns.step))

    conn.products
    |> Enum.filter(&(&1.status in [:needs_selection, :ready]))
    |> Enum.reject(&Map.has_key?(socket.assigns.pickers, &1.key))
    |> Enum.reduce(socket, fn product, acc ->
      scope = acc.assigns.current_scope
      key = product.key
      loader = options_loader()

      acc
      |> put_picker(key, %{
        state: :loading,
        options: [],
        selected: MapSet.new(product.selected),
        query: "",
        error: nil,
        reconnect?: false,
        note: nil
      })
      |> start_async({:options, key}, fn -> loader.(scope, key) end)
    end)
  end

  # Test seam: lets tests stub the provider API call.
  defp options_loader do
    Application.get_env(:metric_flow, :onboarding_options_loader, &Onboarding.list_options/2)
  end

  # ---------------------------------------------------------------------------
  # Async
  # ---------------------------------------------------------------------------

  @impl true
  def handle_async({:options, key}, {:ok, {:ok, options}}, socket) do
    picker = socket.assigns.pickers[key]

    selected =
      case {MapSet.size(picker.selected), options} do
        {0, [only]} -> MapSet.new([to_string(only.id)])
        _ -> picker.selected
      end

    {:noreply,
     update_picker(socket, key, &%{&1 | state: :loaded, options: options, selected: selected})}
  end

  def handle_async({:options, key}, {:ok, {:error, reason}}, socket) do
    {:noreply,
     update_picker(
       socket,
       key,
       &%{
         &1
         | state: :error,
           error: options_error(key, reason),
           reconnect?: reason in [:unauthorized, :token_expired, :missing_youtube_scopes]
       }
     )}
  end

  def handle_async({:options, key}, {:exit, reason}, socket) do
    {:noreply,
     update_picker(
       socket,
       key,
       &%{&1 | state: :error, error: Onboarding.explain_error(reason)}
     )}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("change", %{"product" => product_str} = params, socket) do
    with {:ok, key} <- Onboarding.parse_key(product_str),
         %{} <- socket.assigns.pickers[key] do
      ids = params |> Map.get("ids", []) |> List.wrap() |> MapSet.new()
      query = Map.get(params, "q", "")
      {:noreply, update_picker(socket, key, &%{&1 | selected: ids, query: query, note: nil})}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("select_all", %{"product" => product_str}, socket) do
    with {:ok, key} <- Onboarding.parse_key(product_str),
         %{options: options} <- socket.assigns.pickers[key] do
      ids = MapSet.new(options, &to_string(&1.id))
      {:noreply, update_picker(socket, key, &%{&1 | selected: ids})}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("save", %{"product" => product_str} = params, socket) do
    with true <- socket.assigns.can_modify,
         {:ok, key} <- Onboarding.parse_key(product_str) do
      ids = params |> Map.get("ids", []) |> List.wrap()

      case Onboarding.save_selection(socket.assigns.current_scope, key, ids) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:status, Onboarding.status(socket.assigns.current_scope))
           |> update_picker(
             key,
             &%{&1 | selected: MapSet.new(ids), note: @synced_note, error: nil}
           )}

        {:error, reason} ->
          {:noreply, update_picker(socket, key, &%{&1 | error: Onboarding.explain_error(reason)})}
      end
    else
      false ->
        {:noreply, put_flash(socket, :error, "You are not authorized to change data sources.")}

      _ ->
        {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp put_picker(socket, key, picker),
    do: assign(socket, :pickers, Map.put(socket.assigns.pickers, key, picker))

  defp update_picker(socket, key, fun) do
    case socket.assigns.pickers[key] do
      nil -> socket
      picker -> put_picker(socket, key, fun.(picker))
    end
  end

  defp current_connection(%{step: :done}), do: nil

  defp current_connection(%{step: step, status: status}),
    do: Enum.find(status, &(&1.key == step))

  defp step_done?(:done, status), do: Enum.all?(status, &(&1.state == :done))

  defp step_done?(step, status) do
    case Enum.find(status, &(&1.key == step)) do
      %{state: :done} -> true
      _ -> false
    end
  end

  defp any_product_ready?(conn), do: Enum.any?(conn.products, &(&1.status == :ready))
  defp ready_products(conn), do: Enum.filter(conn.products, &(&1.status == :ready))

  defp step_label(:google), do: "Google"
  defp step_label(:youtube), do: "YouTube"
  defp step_label(:facebook_ads), do: "Meta"
  defp step_label(:quickbooks), do: "QuickBooks"
  defp step_label(:done), do: "Done"

  defp connection_title(%{state: :not_connected, name: name}), do: "Connect #{name}"
  defp connection_title(%{name: name}), do: "#{name}: choose what to sync"

  defp next_step(step) do
    idx = Enum.find_index(@steps, &(&1 == step))
    Enum.at(@steps, idx + 1, :done)
  end

  defp prev_step(step) do
    case Enum.find_index(@steps, &(&1 == step)) do
      0 -> nil
      idx -> Enum.at(@steps, idx - 1)
    end
  end

  defp return_path(key), do: "/app/onboarding/connect?step=#{key}"

  @doc false
  def synced_note, do: @synced_note
end
