defmodule Phoenix.Endpoint.Watcher do
  @moduledoc false
  require Logger

  def child_spec(args) do
    %{
      id: make_ref(),
      start: {__MODULE__, :start_link, [args]},
      restart: :transient
    }
  end

  def start_link({cmd, args}) do
    Task.start_link(__MODULE__, :watch, [to_string(cmd), args])
  end

  def watch(_cmd, {mod, fun, args}) do
    try do
      apply(mod, fun, args)
    catch
      kind, reason ->
        # The function returned a non-zero exit code.
        # Sleep for a couple seconds before exiting to
        # ensure this doesn't hit the supervisor's
        # max_restarts/max_seconds limit.
        Process.sleep(2000)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  def watch(cmd, args) when is_list(args) do
    {args, opts} = Enum.split_while(args, &is_binary(&1))
    opts = Keyword.merge([into: IO.stream(:stdio, :line), stderr_to_stdout: true], opts)

    try do
      System.cmd(cmd, args, opts)
    catch
      :error, :enoent ->
        relative = Path.relative_to_cwd(cmd)

        Logger.error(
          "Could not start watcher #{inspect(relative)} from #{inspect(cd(opts))}, executable does not exist"
        )

        exit(:shutdown)
    else
      {_, 0} ->
        :ok

      {_, _} ->
        # System.cmd returned a non-zero exit code
        # sleep for a couple seconds before exiting to ensure this doesn't
        # hit the supervisor's max_restarts / max_seconds limit
        Process.sleep(2000)
        exit(:watcher_command_error)
    end
  end

  defp cd(opts), do: opts[:cd] || File.cwd!()
end
