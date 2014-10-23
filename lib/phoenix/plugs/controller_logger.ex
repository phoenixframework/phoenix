defmodule Phoenix.Plugs.ControllerLogger do
  import Phoenix.Controller
  require Logger

  @moduledoc """
  Plug to handle request logging at the controller level.


  ## Configuration

  Filter out sensitive parameters in the logs, such as passwords.
  The parameters can be added via the `:filter_parameters` option:

      config :phoenix, :filter_parameters, ["password", "secret"]

  Phoenix's default is `["password"]`.
  """

  def init(opts), do: opts

  def call(conn, _level) do
    Logger.debug fn ->
      module = conn |> controller_module |> inspect
      action = conn |> action_name |> Atom.to_string
      filtered_parameters = conn.params |> filter_parameters

      ["Processing by ", module, ?., action, ?/, ?2, ?\n,
        "  Parameters: ", inspect(filtered_parameters)]
    end
    conn
  end

  defp filter_parameters(params) do
    filter_parameters = Application.get_env(:phoenix, :filter_parameters)
    Enum.into params, %{}, fn {k, v} ->
      if String.contains?(String.downcase(k), filter_parameters) do
        {k, "FILTERED"}
      else
        {k, filter_values(v)}
      end
    end
  end

  defp filter_values(%{} = map),
    do: filter_parameters(map)
  defp filter_values([_|_] = list),
    do: Enum.map(list, fn (item) -> if is_map(item), do: filter_parameters(item), else: item end)
  defp filter_values(other),
    do: other
end
