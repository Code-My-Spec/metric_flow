defmodule MetricFlow.Codemyspec.Client do
  @moduledoc """
  HTTP client for the CodeMySpec API.

  Uses the stored OAuth integration token to communicate with
  the CodeMySpec platform. Requires `cms_gen.integrations` and
  the CodeMySpec provider to be configured.
  """

  alias MetricFlow.Integrations

  @doc """
  Creates an issue on the CodeMySpec platform.

  Attrs should include: title, description, severity, and optionally scope.
  The source is automatically set to "user_feedback".
  Attachments should be a list of maps with s3_key, filename, content_type, size.
  """
  def create_issue(scope, attrs, attachments \\ []) do
    with {:ok, token} <- get_token(scope) do
      url = "#{codemyspec_url()}/api/issues"
      project_id = Application.fetch_env!(:metric_flow, :codemyspec_project_id)

      issue_params =
        attrs
        |> Map.put("source", "user_feedback")
        |> then(fn params ->
          if attachments != [], do: Map.put(params, "attachments", attachments), else: params
        end)

      body = Jason.encode!(%{"issue" => issue_params})

      headers = [
        {"authorization", "Bearer #{token}"},
        {"content-type", "application/json"},
        {"x-project-id", project_id}
      ]

      case Req.post(url, body: body, headers: headers) do
        {:ok, %Req.Response{status: 201, body: body}} ->
          {:ok, body["data"]}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, %{status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Gets a presigned S3 upload URL from CodeMySpec.

  Returns `{:ok, %{upload_url: url, s3_key: key}}` on success.
  """
  def presign_upload(scope, filename, content_type) do
    with {:ok, token} <- get_token(scope) do
      url = "#{codemyspec_url()}/api/uploads/presign"
      project_id = Application.fetch_env!(:metric_flow, :codemyspec_project_id)

      headers = [
        {"authorization", "Bearer #{token}"},
        {"content-type", "application/json"},
        {"x-project-id", project_id}
      ]

      body = Jason.encode!(%{"filename" => filename, "content_type" => content_type})

      case Req.post(url, body: body, headers: headers) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          {:ok, %{upload_url: body["upload_url"], s3_key: body["s3_key"]}}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, %{status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc "Checks if the current user has a CodeMySpec integration."
  def connected?(scope) do
    Integrations.connected?(scope, :codemyspec)
  end

  @doc "Fetches the access token from the user's CodeMySpec integration."
  def get_token(scope) do
    case Integrations.get_integration(scope, :codemyspec) do
      {:ok, integration} -> {:ok, integration.access_token}
      _ -> {:error, :not_connected}
    end
  end

  defp codemyspec_url do
    Application.fetch_env!(:metric_flow, :codemyspec_url)
  end
end
