defmodule Phoenix.Endpoint.Watcher do
  @moduledoc false
  require Logger

  def start_link(root, cmd, args) do
    Task.start_link(__MODULE__, :watch, [root, to_string(cmd), args])
  end

  def watch(root, cmd, args) do
    if exists?(cmd) do
      System.cmd(cmd, args, into: IO.stream(:stdio, :line),
                 stderr_to_stdout: true, cd: root)
    else
      relative = Path.relative_to_cwd(cmd)
      Logger.error "Could not start watcher #{inspect relative}, executable does not exist"
      exit(:shutdown)
    end
  end

  defp exists?(cmd) do
    if Path.type(cmd) == :absolute do
      File.exists?(cmd)
    else
      !!System.find_executable(cmd)
    end
  end
end