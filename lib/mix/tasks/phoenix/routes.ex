defmodule Mix.Tasks.Phoenix.Routes do
  use Mix.Task
  alias Phoenix.Router.ConsoleFormatter

  @shortdoc "Prints routes"
  @recursive true

  @doc """
  Prints routes
  """
  def run([]) do
    router = ConsoleFormatter.default_router

    print_routes(router)
  end

  @doc """
  Prints routes for specified router
  """
  def run([router]) do
    router = String.to_atom("Elixir." <> router)

    print_routes(router)
  end

  defp print_routes(router) do
    Mix.shell.info ConsoleFormatter.format(router)
  end
end
