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
    {:reply, mix_compile, state}
  end

  @doc """
  Run `mix compile` in process against the `web/` directory, ensuring views
  are recompiled where necessary.
  """
  def mix_compile do
    if Code.ensure_loaded?(Mix.Task) do
      touch_views_for_recompile
      Mix.Task.reenable "compile.elixir"
      Mix.Task.run "compile.elixir", ["web"]
    else
      Logger.warn """
      If you want to use the code reload plug in production or inside an escript,
      add :mix to your list of dependencies or disable code reloading"
      """
    end
  end

  defp touch_views_for_recompile do
    Project.view_modules
    |> Enum.filter(fn {_path, view} -> view.recompile? end)
    |> Enum.each fn {path, _view}->
      System.cmd("touch", [path])
    end
  end
end
