defmodule MetricFlowWeb.IntegrationLive.ProviderDashboard do
  @moduledoc """
  Per-provider data dashboard showing synced metrics, sync history, sync controls,
  and connection status for a specific integration provider.

  Route: /integrations/:provider/dashboard
  """

  use MetricFlowWeb, :live_view

  require Logger

  alias MetricFlow.DataSync
  alias MetricFlow.Integrations
  alias MetricFlow.Metrics

  @valid_providers ~w(google_business google_analytics google_ads facebook_ads quickbooks)

  @provider_display_names %{
    "google_business" => "Google Business Profile",
    "google_analytics" => "Google Analytics",
    "google_ads" => "Google Ads",
    "facebook_ads" => "Facebook Ads",
    "quickbooks" => "QuickBooks"
  }

  @provider_metrics %{
    "google_business" => ~w(review_count review_rating call_clicks direction_requests website_clicks),
    "google_analytics" => ~w(sessions activeUsers screenPageViews bounceRate averageSessionDuration),
    "google_ads" => ~w(impressions clicks cost conversions ctr cpc),
    "facebook_ads" => ~w(impressions clicks spend conversions ctr cpc),
    "quickbooks" => ~w(revenue expenses net_income gross_profit cash_on_hand)
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_account_name={assigns[:active_account_name]}>
      <div class="mf-content mx-auto max-w-5xl px-4 py-8">
        <%= if @connected do %>
          <%= render_dashboard(assigns) %>
        <% else %>
          <%= render_empty_state(assigns) %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_dashboard(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <div class="flex flex-wrap items-center gap-3 mb-1">
          <h1 class="text-2xl font-bold">{@provider_name} Dashboard</h1>
          <span class="badge badge-success">Connected</span>
        </div>
        <div :if={@connected_email} class="text-base-content/60 text-sm">{@connected_email}</div>
        <div class="text-base-content/60 text-sm mt-1">
          <%= if @last_synced_at do %>
            Last synced: {format_relative_time(@last_synced_at)}
          <% else %>
            Never synced
          <% end %>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2 mb-6">
        <form phx-change="change_date_range" class="flex items-center gap-2">
          <select name="date_range" class="select select-bordered select-sm">
            <option value="last_7_days" selected={@date_range == "last_7_days"}>Last 7 days</option>
            <option value="last_30_days" selected={@date_range == "last_30_days"}>Last 30 days</option>
            <option value="last_90_days" selected={@date_range == "last_90_days"}>Last 90 days</option>
            <option value="last_12_months" selected={@date_range == "last_12_months"}>Last 12 months</option>
          </select>
        </form>
        <button
          data-role="sync-now"
          phx-click="sync_now"
          class={"btn btn-primary btn-sm #{if @syncing, do: "loading"}"}
          disabled={@syncing}
        >
          <%= if @syncing do %>
            Syncing...
          <% else %>
            Sync Now
          <% end %>
        </button>
        <button phx-click="refresh" class="btn btn-ghost btn-sm">
          Refresh
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div
          :for={metric_name <- @metric_names}
          data-role="metric-card"
          class="mf-card p-5"
        >
          <h3 class="font-semibold mb-2">{humanize_metric(metric_name)}</h3>
          <div class="text-3xl font-bold mb-3">
            {format_metric_value(metric_name, current_value(@metrics, metric_name))}
          </div>
          <div data-role="metric-chart" data-metric={metric_name} class="h-20 w-full">
            <canvas id={"chart-#{metric_name}"} phx-hook="VegaChart" data-spec={Jason.encode!(build_chart_spec(metric_name, @metrics))} class="w-full h-full"></canvas>
          </div>
        </div>
      </div>

      <%= if @provider == "google_business" do %>
        <div data-role="reviews-section" class="mf-card p-5 mb-6">
          <h2 class="text-lg font-semibold mb-4">Recent Reviews</h2>
          <div :if={@reviews == []} class="text-base-content/60 text-sm">
            No reviews available.
          </div>
          <div :for={review <- @reviews} data-role="review-item" class="border-b border-base-200 py-3 last:border-0">
            <div class="flex items-center justify-between mb-1">
              <span class="font-medium">{Map.get(review, :reviewer_name, "Anonymous")}</span>
              <span class="badge badge-ghost text-xs">{Map.get(review, :rating, 0)} ★</span>
            </div>
            <div class="text-base-content/50 text-xs mb-1">{format_date(Map.get(review, :recorded_at))}</div>
            <div class="text-sm line-clamp-2">{Map.get(review, :comment, "")}</div>
          </div>
        </div>
      <% end %>

      <div data-role="sync-history-section" class="mf-card p-5">
        <h2 class="text-lg font-semibold mb-4">Recent Syncs</h2>
        <div :if={@sync_history == []} class="text-base-content/60 text-sm">
          No sync history yet.
        </div>
        <div :for={entry <- @sync_history} data-role="sync-history-row" class="flex items-center gap-3 py-2 border-b border-base-200 last:border-0">
          <div class="flex-1">
            <div class="text-sm">{format_datetime(entry.completed_at)}</div>
          </div>
          <span class={"badge #{status_badge_class(entry.status)}"}>
            {humanize_status(entry.status)}
          </span>
          <div class="text-sm text-base-content/60">{entry.records_synced} records</div>
          <div class="text-sm text-base-content/60">{format_duration(entry)} s</div>
        </div>
      </div>
    </div>
    """
  end

  defp render_empty_state(assigns) do
    ~H"""
    <div data-role="empty-state" class="flex flex-col items-center justify-center py-20 text-center">
      <h2 class="text-xl font-semibold mb-2">Not connected</h2>
      <p class="text-base-content/60 mb-6">
        Connect your {@provider_name} account to start seeing data here.
      </p>
      <.link
        navigate={"/integrations/connect/#{@provider}"}
        class="btn btn-primary"
      >
        Connect {@provider_name}
      </.link>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"provider" => provider}, _session, socket) do
    if provider in @valid_providers do
      scope = socket.assigns.current_scope
      provider_atom = String.to_existing_atom(provider)
      provider_name = Map.fetch!(@provider_display_names, provider)
      metric_names = Map.fetch!(@provider_metrics, provider)

      integration =
        case Integrations.get_integration(scope, provider_atom) do
          {:ok, integration} -> integration
          {:error, _} -> nil
        end

      connected = not is_nil(integration)

      {metrics, sync_history, reviews} =
        if connected do
          load_dashboard_data(scope, provider, provider_atom)
        else
          {%{}, [], []}
        end

      last_synced_at =
        case sync_history do
          [h | _] -> h.completed_at
          [] -> nil
        end

      connected_email =
        if integration, do: get_in(integration.provider_metadata, ["email"]), else: nil

      socket =
        socket
        |> assign(:provider, provider)
        |> assign(:provider_name, provider_name)
        |> assign(:metric_names, metric_names)
        |> assign(:connected, connected)
        |> assign(:integration, integration)
        |> assign(:connected_email, connected_email)
        |> assign(:last_synced_at, last_synced_at)
        |> assign(:date_range, "last_30_days")
        |> assign(:metrics, metrics)
        |> assign(:sync_history, sync_history)
        |> assign(:reviews, reviews)
        |> assign(:syncing, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unknown provider: #{provider}")
       |> redirect(to: "/integrations")}
    end
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("sync_now", _params, socket) do
    scope = socket.assigns.current_scope
    provider_atom = String.to_existing_atom(socket.assigns.provider)

    case DataSync.sync_integration(scope, provider_atom) do
      {:ok, _sync_job} ->
        {:noreply,
         socket
         |> assign(:syncing, true)
         |> put_flash(:info, "Sync started")}

      {:error, reason} ->
        Logger.warning("Failed to start sync for #{socket.assigns.provider}: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to start sync: #{inspect(reason)}")}
    end
  end

  def handle_event("change_date_range", %{"date_range" => date_range}, socket) do
    scope = socket.assigns.current_scope
    provider = socket.assigns.provider
    provider_atom = String.to_existing_atom(provider)

    if socket.assigns.connected do
      metrics = load_metrics(scope, provider_atom, date_range)

      {:noreply,
       socket
       |> assign(:date_range, date_range)
       |> assign(:metrics, metrics)}
    else
      {:noreply, assign(socket, :date_range, date_range)}
    end
  end

  def handle_event("refresh", _params, socket) do
    scope = socket.assigns.current_scope
    provider = socket.assigns.provider
    provider_atom = String.to_existing_atom(provider)
    date_range = socket.assigns.date_range

    if socket.assigns.connected do
      {metrics, sync_history, reviews} = load_dashboard_data(scope, provider, provider_atom, date_range)

      last_synced_at =
        case sync_history do
          [h | _] -> h.completed_at
          [] -> nil
        end

      {:noreply,
       socket
       |> assign(:metrics, metrics)
       |> assign(:sync_history, sync_history)
       |> assign(:reviews, reviews)
       |> assign(:last_synced_at, last_synced_at)
       |> assign(:syncing, false)}
    else
      {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — data loading
  # ---------------------------------------------------------------------------

  defp load_dashboard_data(scope, provider, provider_atom, date_range \\ "last_30_days") do
    metrics = load_metrics(scope, provider_atom, date_range)
    sync_history = load_sync_history(scope)
    reviews = if provider == "google_business", do: load_reviews(scope), else: []
    {metrics, sync_history, reviews}
  end

  defp load_metrics(scope, provider_atom, date_range) do
    metric_names = Map.fetch!(@provider_metrics, Atom.to_string(provider_atom))
    date_range_tuple = date_range_to_tuple(date_range)

    Enum.reduce(metric_names, %{}, fn metric_name, acc ->
      series =
        Metrics.query_time_series(scope, metric_name,
          provider: provider_atom,
          date_range: date_range_tuple
        )

      Map.put(acc, metric_name, series)
    end)
  end

  defp load_sync_history(scope) do
    DataSync.list_sync_history(scope, limit: 5)
  end

  defp load_reviews(scope) do
    Metrics.list_metrics(scope,
      provider: :google_business,
      metric_type: "reviews",
      limit: 10
    )
    |> Enum.map(fn metric ->
      %{
        reviewer_name: get_in(metric.dimensions, ["reviewer_name"]) || "Anonymous",
        rating: get_in(metric.dimensions, ["rating"]) || metric.value,
        recorded_at: metric.recorded_at,
        comment: get_in(metric.dimensions, ["comment"]) || ""
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers — date range
  # ---------------------------------------------------------------------------

  defp date_range_to_tuple("last_7_days") do
    {Date.utc_today() |> Date.add(-7), Date.utc_today()}
  end

  defp date_range_to_tuple("last_30_days") do
    {Date.utc_today() |> Date.add(-30), Date.utc_today()}
  end

  defp date_range_to_tuple("last_90_days") do
    {Date.utc_today() |> Date.add(-90), Date.utc_today()}
  end

  defp date_range_to_tuple("last_12_months") do
    {Date.utc_today() |> Date.add(-365), Date.utc_today()}
  end

  defp date_range_to_tuple(_), do: date_range_to_tuple("last_30_days")

  # ---------------------------------------------------------------------------
  # Private helpers — display
  # ---------------------------------------------------------------------------

  defp current_value(metrics, metric_name) do
    case Map.get(metrics, metric_name, []) do
      [] -> 0.0
      series -> series |> List.last() |> Map.get(:value, 0.0)
    end
  end

  defp format_metric_value(_metric_name, value) when is_nil(value), do: "0"

  defp format_metric_value(metric_name, value)
       when metric_name in ["bounceRate", "ctr"] do
    "#{Float.round(value * 1.0, 1)}%"
  end

  defp format_metric_value(metric_name, value)
       when metric_name in ["cost", "spend", "revenue", "expenses", "net_income", "gross_profit", "cash_on_hand"] do
    "$#{:erlang.float_to_binary(value * 1.0, decimals: 2)}"
  end

  defp format_metric_value("review_rating", value) do
    "#{Float.round(value * 1.0, 1)} ★"
  end

  defp format_metric_value(metric_name, value)
       when metric_name in ["cpc", "averageSessionDuration"] do
    "#{Float.round(value * 1.0, 2)}"
  end

  defp format_metric_value(_metric_name, value) do
    value
    |> trunc()
    |> Integer.to_string()
  end

  defp humanize_metric(metric_name) do
    metric_name
    |> String.replace("_", " ")
    |> split_camel_case()
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp split_camel_case(str) do
    Regex.replace(~r/([A-Z])/, str, " \\1")
  end

  defp humanize_status(:success), do: "Success"
  defp humanize_status(:partial_success), do: "Partial"
  defp humanize_status(:failed), do: "Failed"
  defp humanize_status(status), do: to_string(status)

  defp status_badge_class(:success), do: "badge-success"
  defp status_badge_class(:partial_success), do: "badge-warning"
  defp status_badge_class(:failed), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"

  defp format_relative_time(nil), do: "Never"

  defp format_relative_time(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86_400 -> "#{div(diff, 3600)} hours ago"
      true -> "#{div(diff, 86_400)} days ago"
    end
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end

  defp format_date(nil), do: "—"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d")
  end

  defp format_date(_), do: "—"

  defp format_duration(%{started_at: nil}), do: "—"
  defp format_duration(%{completed_at: nil}), do: "—"

  defp format_duration(entry) do
    entry
    |> MetricFlow.DataSync.SyncHistory.duration()
    |> Integer.to_string()
  end

  defp build_chart_spec(metric_name, metrics) do
    data_points =
      metrics
      |> Map.get(metric_name, [])
      |> Enum.map(fn %{date: date, value: value} ->
        %{"date" => to_string(date), "value" => value}
      end)

    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "data" => %{"values" => data_points},
      "mark" => %{"type" => "line", "interpolate" => "monotone"},
      "encoding" => %{
        "x" => %{"field" => "date", "type" => "temporal", "axis" => %{"labels" => false, "ticks" => false, "title" => nil}},
        "y" => %{"field" => "value", "type" => "quantitative", "axis" => %{"labels" => false, "ticks" => false, "title" => nil}}
      },
      "width" => "container",
      "height" => 80
    }
  end
end
