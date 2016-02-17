defmodule Phoenix.Controller.Logger do
  require Logger

  @behaviour Plug
  import Phoenix.Controller

  alias Phoenix.Endpoint.Instrument

  @moduledoc """
  Plug to handle request logging at the controller level.

  ## Parameter filtering

  When logging parameters, Phoenix can filter out sensitive parameters
  in the logs, such as passwords, tokens and what not. Parameters to
  be filtered can be added via the `:filter_parameters` option:

      config :phoenix, :filter_parameters, ["password", "secret"]

  With the configuration above, Phoenix will filter any parameter
  that contains the terms `password` or `secret`. The match is
  case sensitive.

  Phoenix's default is `["password"]`.
  """

  def init(opts) do
    Keyword.get(opts, :log, :debug)
  end

  def call(conn, false) do
    conn
  end

  def call(conn, level) do
    Logger.log level, fn ->
      module = conn |> controller_module |> inspect
      action = conn |> action_name |> Atom.to_string

      ["Processing by ", module, ?., action, ?/, ?2, ?\n,
        "  Parameters: ", params(conn.params), ?\n,
        "  Pipelines: ", inspect(conn.private[:phoenix_pipelines])]
    end

    conn
  end

  defp params(%Plug.Conn.Unfetched{}), do: "[UNFETCHED]"
  defp params(params) do
    params
    |> Instrument.filter_values(Application.get_env(:phoenix, :filter_parameters))
    |> inspect()
  end
end
