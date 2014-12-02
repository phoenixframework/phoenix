defmodule Phoenix.Controller.Logger do
  require Logger

  @behaviour Plug
  import Phoenix.Controller

  @moduledoc """
  Plug to handle request logging at the controller level.

  ## Parameter filtering

  When loggging parameters, Phoenix can filter out sensitive parameters
  in the logs, such as passwords, tokens and what not. Parameters to
  be filtered can be added via the `:filter_parameters` option:

      config :phoenix, :filter_parameters, ["password", "secret"]

  With the configuration above, Phoenix will filter any parameter
  that contains the terms `password` or `secret`. The match is
  case sensitive.

  Phoenix's default is `["password"]`.
  """

  def init(opts), do: opts

  def call(conn, _level) do
    Logger.debug fn ->
      module = conn |> controller_module |> inspect
      action = conn |> action_name |> Atom.to_string
      params = filter_values(conn.params, Application.get_env(:phoenix, :filter_parameters))

      ["Processing by ", module, ?., action, ?/, ?2, ?\n,
        "  Parameters: ", inspect(params), ?\n,
        "  Pipeline: ", inspect(conn.private[:phoenix_pipelines])]
    end

    conn
  end

  defp filter_values(%{__struct__: mod} = struct, _filter_params) when is_atom(mod) do
    struct
  end
  defp filter_values(%{} = map, filter_params) do
    Enum.into map, %{}, fn {k, v} ->
      if String.contains?(k, filter_params) do
        {k, "[FILTERED]"}
      else
        {k, filter_values(v, filter_params)}
      end
    end
  end
  defp filter_values([_|_] = list, filter_params) do
    Enum.map(list, &filter_values(&1, filter_params))
  end
  defp filter_values(other, _filter_params), do: other
end
