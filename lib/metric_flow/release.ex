defmodule MetricFlow.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :metric_flow

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn started_repo ->
          Ecto.Migrator.run(started_repo, :up, all: true)
          migrations = Ecto.Migrator.migrations(started_repo)

          if Enum.any?(migrations, fn {status, _, _} -> status != :up end) do
            raise "migration verification failed: pending migrations remain for #{inspect(repo)}"
          end

          version =
            migrations |> Enum.map(fn {_, version, _} -> version end) |> Enum.max(fn -> 0 end)

          # CodeMySpec's deploy refuses a migrate step that doesn't print this
          # proof line (`migrated=<version>`), even when the migrations ran.
          IO.puts("migrated=#{version}")
        end)
    end

    :ok
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
