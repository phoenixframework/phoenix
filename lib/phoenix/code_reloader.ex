defmodule Phoenix.CodeReloader do
  use GenServer
  require Logger

  @moduledoc """
  Server to handle automatic code reloading

  For each request, Phoenix checks if any of the modules previously
  compiled requires recompilation via `__phoenix_recompile__?/0` and then
  calls `mix compile` for sources exclusive to the `web` directory.

  To race conditions, all code reloads are funneled through a sequential
  call operation.
  """

  @doc """
  Starts the code reloader server

  The code reloader server is automatically started by Phoenix.
  """
  def start_link do
    GenServer.start_link __MODULE__, [], name: __MODULE__
  end

  @doc """
  Reloads codes witin `web/` directory
  """
  def reload! do
    GenServer.call __MODULE__, :reload, :infinity
  end

  @doc """
  Touches sources that should be recompiled

  This works by checking each compiled Phoenix module if
  `phoenix_recompiled?/0` returns true and if so it touches
  it sources file.
  """
  def touch do
    Mix.Phoenix.modules
    |> modules_for_recompilation
    |> modules_to_file_paths
    |> Stream.each(&File.touch/1)
    |> Enum.to_list()
  end

  ## Callbacks

  def init(_opts) do
    {:ok, :nostate}
  end

  def handle_call(:reload, from, state) do
    froms = all_waiting([from])
    reply = mix_compile(Code.ensure_loaded(Mix.Task))
    Enum.each(froms, &GenServer.reply(&1, reply))
    {:noreply, state}
  end

  defp all_waiting(acc) do
    receive do
      {:"$gen_call", from, :reload} -> all_waiting([from | acc])
    after
      0 -> acc
    end
  end

  defp mix_compile({:error, _reason}) do
    Logger.error "If you want to use the code reload plug in production or " <>
                 "inside an escript, add :mix to your list of dependencies or " <>
                 "disable code reloading"
  end

  defp mix_compile({:module, Mix.Task}) do
    touch()
    Mix.Task.reenable "compile.elixir"
    Mix.Task.run "compile.elixir", ["--elixirc-paths", "web"]
  end

  defp modules_for_recompilation(modules) do
    modules
    |> Stream.filter fn mod ->
      Code.ensure_loaded?(mod) and
        function_exported?(mod, :__phoenix_recompile__?, 0) and
        mod.__phoenix_recompile__?
    end
  end

  defp modules_to_file_paths(modules) do
    Stream.map(modules, fn mod -> mod.__info__(:compile)[:source] end)
  end
end
