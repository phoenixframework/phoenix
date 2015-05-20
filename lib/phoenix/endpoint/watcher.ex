defmodule Phoenix.Endpoint.Watcher do
  @moduledoc false
  require Logger

  def start_link(root, cmd, args) do
    Task.start_link(__MODULE__, :watch, [root, to_string(cmd), args])
  end

  def watch(root, cmd, args) do
    :ok = validate(root, cmd, args)

    try do
      System.cmd(cmd, args, into: IO.stream(:stdio, :line),
                            stderr_to_stdout: true, cd: root)
    catch
      :error, :enoent ->
        relative = Path.relative_to_cwd(cmd)
        Logger.error "Could not start watcher #{inspect relative}, executable does not exist"
        exit(:shutdown)
    end
  end

  # We specially handle node to make sure we
  # provide a good getting started experience.
  defp validate(root, "node", [script|_]) do
    if File.exists?(Path.expand(script, root)) do
      :ok
    else
      Logger.error "Could not start node watcher because script #{inspect script} does not " <>
                   "exist. Please make sure it has been installed by running: npm install"
      exit(:shutdown)
    end
  end

  defp validate(_root, _cmd, _args) do
    :ok
  end
end
