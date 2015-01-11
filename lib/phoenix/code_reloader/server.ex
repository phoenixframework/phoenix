# The GenServer used by the CodeReloader.
defmodule Phoenix.CodeReloader.Server do
  @moduledoc false
  use GenServer

  require Logger
  alias Phoenix.CodeReloader.Proxy

  def start_link do
    GenServer.start_link __MODULE__, [], name: __MODULE__
  end

  def reload!(paths) do
    GenServer.call __MODULE__, {:reload!, paths}, :infinity
  end

  ## Callbacks

  def init(_opts) do
    {:ok, :nostate}
  end

  def handle_call({:reload!, paths}, from, state) do
    froms = all_waiting([from])
    reply = mix_compile(Code.ensure_loaded(Mix.Task), paths)
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

  defp mix_compile({:error, _reason}, _) do
    Logger.error "If you want to use the code reload plug in production or " <>
                 "inside an escript, add :mix to your list of dependencies or " <>
                 "disable code reloading"
  end

  defp mix_compile({:module, Mix.Task}, paths) do
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
