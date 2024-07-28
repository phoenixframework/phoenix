defmodule <%= app_namespace %>.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :<%= otp_app %>

  def wait_for_migrations do
    load_app()
    all_migrated? = repos()
    |> Stream.map(&migrated?/1)
    |> Enum.all?()
    if not all_migrated? do
      raise "Migrations have still not run after the timeout"
    end
    IO.puts("Migration check successful!")
  end

  defp migrated?(repo, retry_count \\ 0)
  defp migrated?(_, retry_count) when retry_count > 60 do false end
  defp migrated?(repo, retry_count) when retry_count > 0 do
    IO.puts("Waiting for migrations to run for #{repo} (#{retry_count}/60)...")
    Process.sleep(5000)
    do_migration_check(repo, retry_count)
  end

  defp migrated?(repo, retry_count) do
    do_migration_check(repo, retry_count)
  end

  defp do_migration_check(repo, retry_count) do
    case Ecto.Migrator.with_repo(repo, &Ecto.Migrator.migrations(&1)) do
      {:ok, repo_status, _} ->
        Enum.all?(repo_status, fn {status, _, _} -> status == :up end) || migrated?(repo, retry_count + 1)
      {:error, error} ->
        IO.puts(error)
        migrated?(repo, retry_count + 1)
    end
  end

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
