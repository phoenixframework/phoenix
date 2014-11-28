defmodule Phoenix.Controller.Logger do
  require Logger

  @behaviour Plug
  import Phoenix.Controller

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
      filter_params =
        Application.get_env(:phoenix, :filter_parameters)
        |> Enum.map(&String.downcase(&1))
      filtered_parameters = conn.params |> filter_sensitive_values(filter_params)

      ["Processing by ", module, ?., action, ?/, ?2, ?\n,
        "  Parameters: ", inspect(filtered_parameters), ?\n,
        "  Pipeline: ", inspect(conn.private[:phoenix_pipelines])]
    end

    conn
  end

  defp filter_sensitive_values(params, filter_params) do
    Enum.into params, %{}, fn {k, v} ->
      if String.contains?(String.downcase(k), filter_params) do
        {k, "FILTERED"}
      else
        {k, filter_value(v, filter_params)}
      end
    end
  end

  defp filter_value(%{} = map, filter_params) do
    filter_sensitive_values(map, filter_params)
  end
  defp filter_value([_|_] = list, filter_params) do
    Enum.map(list, &filter_value(&1, filter_params))
  end
  defp filter_value(other, _filter_params), do: other
end
