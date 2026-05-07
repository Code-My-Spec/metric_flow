defmodule MetricFlow.Secrets do
  @moduledoc """
  Boot-time secret loader. Pulls every parameter under
  `/metric_flow/<APP_ENV>/` from AWS SSM Parameter Store and writes it
  into the OS environment so the rest of `config/runtime.exs` (which
  uses `Dotenvy.env!/3` over `System.get_env`) sees the values as if
  they were set in the container's launch env.

  Invoked from the top of `config/runtime.exs` in `:prod` (i.e. on UAT
  and prod boxes — both compile with `MIX_ENV=prod`). Local dev does not
  call this — dev secrets come from `.env` files via Dotenvy.

  ## Why fetch at runtime, not deploy-time

  Operator-side secret rendering (the prior `render-env` script) sourced
  every secret into the operator's interactive shell before invoking
  Kamal. A buggy substitution accidentally printed all of them to a
  session transcript on 2026-05-06. Fetching at boot inside the
  container removes that vector entirely — Kamal carries only AWS
  bootstrap credentials, never the app secrets themselves.

  ## IAM

  Uses the standard ExAws credential chain. The container needs an IAM
  principal scoped to:
  - `ssm:GetParametersByPath` on
    `arn:aws:ssm:us-east-1:889081505590:parameter/metric_flow/<env>/*`
    (per-app, per-env user — `metric-flow-<env>-app`)
  - `kms:Decrypt` on the SSM service KMS key (the default `aws/ssm`
    AWS-managed key, free, encrypts SecureString parameters at rest)

  Creds are passed in via `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`,
  region defaults to `AWS_REGION` (set to us-east-1 in our deploys).
  Both are wired through Kamal's `env.secret` in `config/deploy.yml` and
  `config/deploy.uat.yml`.

  ## Boot lifecycle

  `runtime.exs` runs BEFORE the application supervisor starts. The OTP
  apps `ex_aws_ssm` and `hackney` are listed in `mix.exs`'s
  `extra_applications` so they're loaded with the release, but they
  aren't *started* until after `runtime.exs` finishes. We start them
  explicitly here so `ExAws.request/1` has a working HTTP client. After
  `runtime.exs` returns, OTP picks up supervision in the normal way.
  """

  @path_prefix "/metric_flow/"

  # Retry tuning. SSM rate limits are generous (40 TPS standard tier);
  # the typical failure here is a transient network blip during a
  # box-wide restart, not throttling. 3 attempts covers a ~6s outage
  # without inflating boot time during the happy path.
  @max_attempts 3
  @backoff_ms 1000

  @doc """
  Load all parameters for `app_env` ("prod" | "uat") and put them in
  System env. Raises on missing IAM creds, no parameters under the
  path, or any SSM error after `#{@max_attempts}` retry attempts.
  """
  @spec load!(String.t()) :: :ok
  def load!(app_env) when app_env in ["prod", "uat"] do
    # Apps are listed in extra_applications (mix.exs), loaded with the
    # release, but not started until after runtime.exs finishes — start
    # explicitly here so ExAws has a HTTP client.
    {:ok, _} = Application.ensure_all_started(:ex_aws)
    {:ok, _} = Application.ensure_all_started(:hackney)

    path = @path_prefix <> app_env <> "/"

    parameters = fetch_all(path, nil, [])

    if parameters == [] do
      raise """
      No SSM parameters found under #{path}.
      Verify AWS credentials and that the path has parameters.
      """
    end

    Enum.each(parameters, fn %{"Name" => name, "Value" => value} ->
      key = String.replace_prefix(name, path, "")
      System.put_env(key, value)
    end)

    :ok
  end

  def load!(other),
    do: raise(ArgumentError, "MetricFlow.Secrets.load!/1: unsupported APP_ENV #{inspect(other)}")

  defp fetch_all(path, next_token, acc) do
    case fetch_page(path, next_token) do
      {:ok, %{"Parameters" => params, "NextToken" => token}} when is_binary(token) ->
        # Prepend per page; flatten + concat once at the end. Avoids
        # O(n^2) ++ for large parameter trees.
        fetch_all(path, token, [params | acc])

      {:ok, %{"Parameters" => params}} ->
        Enum.reverse([params | acc]) |> List.flatten()
    end
  end

  # Single SSM page request with bounded retry. The backoff is fixed
  # rather than exponential because the worst case we're guarding
  # against is a brief network partition, not sustained AWS throttling.
  defp fetch_page(path, next_token, attempt \\ 1) do
    opts = [recursive: true, with_decryption: true]
    opts = if next_token, do: Keyword.put(opts, :next_token, next_token), else: opts

    case ExAws.SSM.get_parameters_by_path(path, opts) |> ExAws.request() do
      {:ok, page} ->
        {:ok, page}

      {:error, _reason} when attempt < @max_attempts ->
        # Deliberately drop `reason` — it can include partial AWS auth
        # diagnostics. Log only the bounded fields.
        :logger.warning(
          "MetricFlow.Secrets: SSM fetch failed for #{path} (attempt #{attempt}/#{@max_attempts}); retrying in #{@backoff_ms}ms"
        )

        Process.sleep(@backoff_ms)
        fetch_page(path, next_token, attempt + 1)

      {:error, reason} ->
        raise """
        MetricFlow.Secrets.load!/1: SSM fetch failed for #{path} after \
        #{@max_attempts} attempts: #{inspect(reason)}
        """
    end
  end
end
