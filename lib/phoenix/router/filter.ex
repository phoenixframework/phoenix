defmodule Phoenix.Router.Filter do
  def run_controller_filters(conn, controller, action) do
    if plug?(controller) do
      conn = Plug.Connection.assign_private(conn, :phoenix_context,
        [ controller: controller, action: action ])

      controller.call(conn, [])
    else
      conn
    end
  end

  defp plug?(module) do
    { :module, module } = Code.ensure_loaded(module)
    function_exported?(module, :call, 2)
  end
end
