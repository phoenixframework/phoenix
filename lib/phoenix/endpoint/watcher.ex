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
    cond do
      !System.find_executable("node") ->
        Logger.error "Could not start watcher because \"node\" is not available. Your Phoenix " <>
                     "application is still running, however assets won't be compiled. " <>
                     "You may fix this by installing \"node\" and then running \"npm install\"."
        exit(:shutdown)

      !File.exists?(Path.expand(script, root)) ->
        Logger.error "Could not start node watcher because script #{inspect script} does not " <>
                     "exist. Your Phoenix application is still running, however assets " <>
                     "won't be compiled. You may fix this by running \"npm install\"."
        exit(:shutdown)

      true ->
        :ok
    end
  end

  defp validate(_root, _cmd, _args) do
    :ok
  end
end
