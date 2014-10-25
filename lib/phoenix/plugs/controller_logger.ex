defmodule Phoenix.Plugs.ControllerLogger do
  import Phoenix.Controller
  require Logger

  @moduledoc """
  Plug to handle request logging at the controller level.
  """

  def init(opts), do: opts

  def call(conn, _level) do
    Logger.debug fn ->
      format = case Map.fetch(conn.params, "format") do
        {:ok, format} -> ["  Format: ", format, ?\n]
        :error -> []
      end

      module = conn |> controller_module |> inspect
      action = conn |> action_name |> Atom.to_string

      ["Processing by ", module, ?., action, ?/, ?2, ?\n,
        format,
        "  Parameters: ", inspect(conn.params)]
    end
    conn
  end
end
