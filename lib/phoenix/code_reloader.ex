defmodule Phoenix.CodeReloader do
  use GenServer
  require Logger

  @moduledoc """
  Server to handle automatic Code reloading in development.

  `mix compile` is run in process for the `web/` directory. Applicaton
  Views are automatically recompiled with their file list changes. To
  prevent module redefinition errors, all code reloads are funneled through
  a sequential call operation.
  """

  @doc """
  Reloads codes witin `web/` directory
  """
  def reload! do
    GenServer.call __MODULE__, :reload
  end

  @doc false
  def start_link do
    GenServer.start_link __MODULE__, [], name: __MODULE__
  end

  @doc false
  def init(_opts) do
    {:ok, :nostate}
  end

  @doc false
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

  @doc """
  Run `mix compile` in process against the `web/` directory, ensuring views
  are recompiled where necessary.
  """
  def mix_compile({:error, _reason}) do
    Logger.warn """
    If you want to use the code reload plug in production or inside an escript,
    add :mix to your list of dependencies or disable code reloading"
    """
  end
  def mix_compile({:module, Mix.Task}) do
    touch_modules_for_recompile
    mix_compile_env(Mix.env)
  end
  defp mix_compile_env(:test) do
    reload_modules_for_recompile
  end
  defp mix_compile_env(_env) do
    Mix.Task.reenable "compile.elixir"
    Mix.Task.run "compile.elixir", ["--ignore-module-conflict", "--elixirc-paths", "web"]
  end

  defp touch_modules_for_recompile do
    Mix.Phoenix.modules
    |> modules_for_recompilation
    |> modules_to_file_paths
    |> Enum.each(&File.touch!(&1))
  end

  defp reload_modules_for_recompile do
    Mix.Phoenix.modules
    |> modules_for_recompilation
    |> Enum.each(&IEx.Helpers.r(&1))
  end

  defp modules_for_recompilation(modules) do
    modules
    |> Stream.filter fn mod ->
      Code.ensure_loaded?(mod) and
        function_exported?(mod, :phoenix_recompile?, 0) and
        mod.phoenix_recompile?
    end
  end
  defp modules_to_file_paths(modules) do
    Stream.map(modules, fn mod -> mod.__info__(:compile)[:source] end)
  end
end
