defmodule Phoenix.CodeReloader do
  use GenServer
  require Logger
  alias Phoenix.Project

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
  def handle_call(:reload, _from, state) do
    {:reply, mix_compile(Code.ensure_loaded(Mix.Task)), state}
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
    Mix.Task.reenable "compile.elixir"
    Mix.Task.run "compile.elixir", ["web"]
  end

  defp touch_modules_for_recompile do
    Project.modules
    |> modules_for_recompilation
    |> modules_to_file_paths
    |> Enum.each(&File.touch!(&1))
  end
  defp modules_for_recompilation(modules) do
    modules
    |> Stream.filter(fn mod -> function_exported?(mod, :phoenix_recompile?, 0) end)
    |> Stream.filter(fn mod -> mod.phoenix_recompile? end)
  end
  defp modules_to_file_paths(modules) do
    Stream.map(modules, fn mod -> mod.__info__(:compile)[:source] end)
  end
end
