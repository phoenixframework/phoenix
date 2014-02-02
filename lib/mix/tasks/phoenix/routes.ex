defmodule Mix.Tasks.Phoenix.Routes do
  use Mix.Task

  @shortdoc "Prints routes"
  @recursive true

  @doc """
  Prints routes
  """
  def run([]) do
    routes = project_module.Config.Router.__routes__

    Mix.shell.info format_routes(routes)
  end

  def format_routes(routes) do
    column_widths = calculate_column_widths(routes)
    formatted_routes = lc route inlist routes, do: format_route(route, column_widths)

    Enum.join(formatted_routes, "\n")
  end

  defp calculate_column_widths(routes) do
    Enum.reduce routes, [0, 0, 0], fn(route, acc) ->
      {method, path, controller, action, options} = route
      [method_len, path_len, route_name_len] = acc
      route_name = Keyword.get(options, :as, :"")

      [max(method_len, String.length(atom_to_binary(method))),
       max(path_len, String.length(path)),
       max(route_name_len, String.length(atom_to_binary(route_name)))]
    end
  end

  defp format_route(route, column_widths) do
    {method, path, controller, action, options} = route
    route_name = Keyword.get(options, :as, :"")
    [method_len, path_len, route_name_len] = column_widths

    controller_name = String.replace(atom_to_binary(controller), atom_to_binary(project_module.Controllers) <> ".", "")

    String.rjust(atom_to_binary(route_name), route_name_len) <> "  " <>
    String.ljust(String.upcase(atom_to_binary(method)), method_len) <> "  " <>
    String.ljust(path, path_len) <> "  " <>
    controller_name <> "#" <> atom_to_binary(action)
  end

  defp project_module do
    project_name = Keyword.get Mix.project, :app

    binary_to_atom(Mix.Utils.camelize(atom_to_binary(project_name)))
  end
end
