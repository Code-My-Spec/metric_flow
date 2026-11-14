defmodule MetricFlowWeb.AgencyLive.LogoUpload do
  @moduledoc "Shared upload lifecycle for agency branding settings."

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  alias MetricFlow.Agencies

  def configure(socket) do
    socket
    |> assign(:pending_logo, nil)
    |> allow_upload(:logo,
      accept: ~w(.png .jpg .jpeg .svg),
      max_entries: 1,
      max_file_size: 2_000_000,
      auto_upload: true,
      external: &presign/2,
      progress: &progress/3
    )
  end

  def merge_params(socket, params) do
    case socket.assigns.pending_logo do
      %{account_id: id, url: url} ->
        if id == account_id(socket), do: Map.put(params, "logo_url", url), else: params

      nil ->
        params
    end
  end

  def clear(socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.logo.entries, socket, fn entry, acc ->
        cancel_upload(acc, :logo, entry.ref)
      end)

    assign(socket, :pending_logo, nil)
  end

  defp presign(entry, socket) do
    id = account_id(socket)

    case Agencies.presign_logo_upload(socket.assigns.current_scope, id, entry) do
      {:ok, metadata} ->
        {:ok, Map.put(metadata, :account_id, id), socket}

      {:error, _reason} ->
        {:error, %{reason: "Logo upload is unavailable. Please try again later."},
         put_flash(
           socket,
           :error,
           "Unable to upload this logo. Check your access and storage configuration."
         )}
    end
  end

  defp progress(:logo, entry, socket) do
    socket =
      if entry.done? do
        pending =
          consume_uploaded_entry(socket, entry, fn metadata ->
            {:ok, %{account_id: metadata.account_id, url: metadata.public_url}}
          end)

        assign(socket, :pending_logo, pending)
      else
        socket
      end

    {:noreply, socket}
  end

  defp account_id(%{assigns: %{account: account}}), do: account.id
  defp account_id(%{assigns: %{account_id: id}}), do: id
end
