# The GenServer used by the CodeReloader.
defmodule Phoenix.CodeReloader.Server do
  @moduledoc false
  use GenServer

  require Logger
  alias Phoenix.CodeReloader.Proxy

  def start_link(app, root, paths) do
    GenServer.start_link(__MODULE__, {app, root, paths})
  end

  def reload!(endpoint) do
    children = Supervisor.which_children(endpoint)

    case List.keyfind(children, __MODULE__, 0) do
      {__MODULE__, pid, _, _} ->
        GenServer.call(pid, :reload!, :infinity)
      _ ->
        # TODO: Improve this error message once users have migrated
        raise "Code reloader was invoked for #{inspect endpoint} but no code reloader " <>
              "server was started. Be sure to move `plug Phoenix.CodeReloader` inside " <>
              "a `if code_reloading? do` block"
    end
  end

  ## Callbacks

  def init({app, root, paths}) do
    {:ok, {app, root, paths}}
  end

  def handle_call(:reload!, from, {app, root, paths} = state) do
    froms = all_waiting([from])
    reply = mix_compile(Code.ensure_loaded(Mix.Task), app, root, paths)
    Enum.each(froms, &GenServer.reply(&1, reply))
    {:noreply, state}
  end

  defp all_waiting(acc) do
    receive do
      {:"$gen_call", from, :reload!} -> all_waiting([from | acc])
    after
      0 -> acc
    end
  end

  defp mix_compile({:error, _reason}, _, _, _) do
    Logger.error "If you want to use the code reload plug in production or " <>
                 "inside an escript, add :mix to your list of dependencies or " <>
                 "disable code reloading"
  end

  defp mix_compile({:module, Mix.Task}, app, root, paths) do
    if Mix.Project.umbrella? do
      Mix.Project.in_project(app, root, fn _ -> mix_compile(paths) end)
    else
      mix_compile(paths)
    end
  end

  defp mix_compile(paths) do
    reloadable_paths = Enum.flat_map(paths, &["--elixirc-paths", &1])
    Mix.Task.reenable "compile.phoenix"
    Mix.Task.reenable "compile.elixir"

    {res, out} =
      proxy_io(fn ->
        try do
          Mix.Task.run "compile.phoenix"
          Mix.Task.run "compile.elixir", reloadable_paths
        catch
          _, _ -> :error
        end
      end)

    cond do
      :error in res -> {:error, out}
      :ok in res    -> :ok
      true          -> :noop
    end
  end

  defp proxy_io(fun) do
    original_gl = Process.group_leader
    {:ok, proxy_gl} = Proxy.start()
    Process.group_leader(self(), proxy_gl)

    try do
      res = fun.()
      {List.wrap(res), Proxy.stop(proxy_gl)}
    after
      Process.group_leader(self(), original_gl)
      Process.exit(proxy_gl, :kill)
    end
  end
end
