defmodule Phoenix.Controller.Instrumenter do
  @moduledoc """
  Instrumenter to handle request logging at the controller level.

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
  require Logger
  import Phoenix.Controller

  alias Phoenix.Endpoint.Instrument


  def phoenix_controller_call(:start, _compile, %{log_level: false}), do: :ok
  def phoenix_controller_call(:start, %{module: module}, %{log_level: level, conn: conn}) do
    Logger.log level, fn ->
      controller = inspect(module)
      action = conn |> action_name() |> Atom.to_string()
      ["Processing by ", controller, ?., action, ?/, ?2, ?\n,
        "  Parameters: ", params(conn.params), ?\n,
        "  Pipelines: ", inspect(conn.private[:phoenix_pipelines])]
    end
  end

  def phoenix_controller_call(:stop, _time_diff, _context), do: :ok

  defp params(%Plug.Conn.Unfetched{}), do: "[UNFETCHED]"
  defp params(params) do
    params
    |> Instrument.filter_values(Application.get_env(:phoenix, :filter_parameters))
    |> inspect()
  end
end
