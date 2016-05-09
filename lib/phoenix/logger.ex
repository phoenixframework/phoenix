defmodule Phoenix.Logger do
  @moduledoc """
  Instrumenter to handle logging of various instrumentation events.

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


  def phoenix_controller_call(:start, _compile, %{log_level: false}), do: :ok
  def phoenix_controller_call(:start, %{module: module}, %{log_level: level, conn: conn}) do
    Logger.log level, fn ->
      controller = inspect(module)
      action = conn |> action_name() |> Atom.to_string()
      ["Processing by ", controller, ?., action, ?/, ?2, ?\n,
        "  Parameters: ", params(conn.params), ?\n,
        "  Pipelines: ", inspect(conn.private[:phoenix_pipelines])]
    end
    :ok
  end
  def phoenix_controller_call(:stop, _time_diff, :ok), do: :ok

  def phoenix_channel_join(:start, _compile, %{socket: socket, params: params}) do
    log_join(socket.topic, socket, params)
  end
  def phoenix_channel_join(:stop, _compile, :ok), do: :ok

  defp log_join("phoenix" <> _, _socket, _params), do: :ok
  defp log_join(topic, socket, params) do
    filtered_params = filter_values(params)
    Logger.info fn ->
      "JOIN #{topic} to #{inspect(socket.channel)}\n" <>
      "  Transport:  #{inspect socket.transport}\n" <>
      "  Parameters: #{inspect filtered_params}"
    end
  end

  @doc false
  def filter_values(values, params \\ Application.get_env(:phoenix, :filter_parameters))
  def filter_values(%{__struct__: mod} = struct, _filter_params) when is_atom(mod) do
    struct
  end
  def filter_values(%{} = map, filter_params) do
    Enum.into map, %{}, fn {k, v} ->
      if is_binary(k) and String.contains?(k, filter_params) do
        {k, "[FILTERED]"}
      else
        {k, filter_values(v, filter_params)}
      end
    end
  end
  def filter_values([_|_] = list, filter_params) do
    Enum.map(list, &filter_values(&1, filter_params))
  end
  def filter_values(other, _filter_params), do: other

  defp params(%Plug.Conn.Unfetched{}), do: "[UNFETCHED]"
  defp params(params) do
    params
    |> filter_values()
    |> inspect()
  end
end
