defmodule Phoenix.Router.RouteHelper do
  alias Phoenix.Router.Path

  @moduledoc """
  Builds named route helpers for Routers to regenerate defined route paths
  """

  def defhelpers(routes, module) do
    path_helpers_ast = for route <- routes, do: Phoenix.Router.Route.helper_definition(route)

    quote do
      unquote(path_helpers_ast)
      # TODO: use host/port/schem from Conn
      def url(_conn = %Plug.Conn{}, path), do: url(path)
      def url(path) do
        Path.build_url(path, [], [], unquote(module))
      end
    end
  end
end
