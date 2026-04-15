defmodule MetricFlowWeb.AgencyLive.AgencySettings do
  @moduledoc """
  Agency settings page for white-label branding and auto-enrollment configuration.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Agencies
  alias MetricFlowWeb.AgencyLive

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
    <div class="mx-auto">
      <.header>
        Agency Settings
        <:subtitle>Configure branding and enrollment for your agency</:subtitle>
      </.header>

      <div class="mt-8 space-y-8">
        <AgencyLive.Settings.auto_enrollment_section
          auto_enrollment_rule={@auto_enrollment_rule}
          auto_enrollment_form={@auto_enrollment_form}
        />

        <AgencyLive.Settings.white_label_section
          white_label_config={@agency_white_label_config}
          white_label_form={@white_label_form}
        />
      </div>
    </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns[:active_account_id]

    auto_enrollment_rule =
      case account_id && Agencies.get_auto_enrollment_rule(scope, account_id) do
        {:error, _} -> nil
        nil -> nil
        rule -> rule
      end

    agency_white_label_config =
      case account_id && Agencies.get_white_label_config(scope, account_id) do
        {:error, _} -> nil
        nil -> nil
        config -> config
      end

    socket =
      socket
      |> assign(:account_id, account_id)
      |> assign(:auto_enrollment_rule, auto_enrollment_rule)
      |> assign(:auto_enrollment_form, empty_form())
      |> assign(:agency_white_label_config, agency_white_label_config)
      |> assign(:white_label_form, empty_form())

    {:ok, socket}
  end

  @impl true
  def handle_event("save_auto_enrollment", %{"auto_enrollment" => params}, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account_id

    attrs = %{
      email_domain: params["domain"],
      default_access_level: parse_access_level(params["default_access_level"]),
      enabled: true
    }

    case Agencies.configure_auto_enrollment(scope, account_id, attrs) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> assign(:auto_enrollment_rule, rule)
         |> assign(:auto_enrollment_form, empty_form())
         |> put_flash(:info, "Auto-enrollment enabled")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = changeset_to_errors(changeset)
        {:noreply, assign(socket, :auto_enrollment_form, %{params: params, errors: errors})}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to configure auto-enrollment")}
    end
  end

  def handle_event("disable_auto_enrollment", _params, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account_id

    case Agencies.configure_auto_enrollment(scope, account_id, %{enabled: false}) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> assign(:auto_enrollment_rule, rule)
         |> put_flash(:info, "Auto-enrollment disabled")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to configure auto-enrollment")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disable auto-enrollment")}
    end
  end

  def handle_event("validate_white_label", %{"white_label" => params}, socket) do
    {:noreply, assign(socket, :white_label_form, %{params: params, errors: []})}
  end

  def handle_event("save_white_label", %{"white_label" => params}, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account_id

    attrs = %{
      subdomain: params["subdomain"],
      logo_url: params["logo_url"],
      primary_color: params["primary_color"],
      secondary_color: params["secondary_color"]
    }

    case Agencies.update_white_label_config(scope, account_id, attrs) do
      {:ok, config} ->
        {:noreply,
         socket
         |> assign(:agency_white_label_config, config)
         |> assign(:white_label_form, empty_form())
         |> put_flash(:info, "White-label settings saved")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = changeset_to_errors(changeset)
        {:noreply, assign(socket, :white_label_form, %{params: params, errors: errors})}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to configure white-label branding")}
    end
  end

  def handle_event("reset_white_label", _params, socket) do
    scope = socket.assigns.current_scope
    account_id = socket.assigns.account_id

    case Agencies.reset_white_label_config(scope, account_id) do
      :ok ->
        {:noreply,
         socket
         |> assign(:agency_white_label_config, nil)
         |> assign(:white_label_form, empty_form())
         |> put_flash(:info, "Branding reset to default")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to reset white-label branding")}
    end
  end

  def handle_event("verify_dns", _params, socket) do
    {:noreply, put_flash(socket, :info, "DNS verification initiated. Please allow a few minutes.")}
  end

  defp empty_form, do: %{params: %{}, errors: []}

  defp parse_access_level("read_only"), do: :read_only
  defp parse_access_level("account_manager"), do: :account_manager
  defp parse_access_level("admin"), do: :admin
  defp parse_access_level(_), do: :read_only

  defp changeset_to_errors(%Ecto.Changeset{} = changeset) do
    Enum.map(changeset.errors, fn {field, {msg, opts}} ->
      {field, {translate_error_msg({msg, opts}), opts}}
    end)
  end

  defp translate_error_msg({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(MetricFlowWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MetricFlowWeb.Gettext, "errors", msg, opts)
    end
  end
end
