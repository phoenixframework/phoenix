defmodule Phoenix.Plugs.ControllerLogger do
  import Phoenix.Controller
  require Logger

  @moduledoc """
  Plug to handle request logging at the controller level.
  """

  def init(opts), do: opts

  def call(conn, _level) do
    Logger.debug fn ->
      module = conn |> controller_module |> inspect
      action = conn |> action_name |> Atom.to_string

      ["Processing by ", module, ?., action, ?/, ?2, ?\n,
        "  Parameters: ", inspect(conn.params), ?\n,
        "  Pipeline: ", inspect(conn.private[:phoenix_pipelines])]
    end
    conn
  end
end
