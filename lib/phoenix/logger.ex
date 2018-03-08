defmodule Phoenix.Logger do
  @moduledoc """
  Instrumenter to handle logging of various instrumentation events.

  ## Parameter filtering

  When logging parameters, Phoenix can filter out sensitive parameters
  such as passwords and tokens. Parameters to be filtered can be
  added via the `:filter_parameters` option:

      config :phoenix, :filter_parameters, ["password", "secret"]

  With the configuration above, Phoenix will filter any parameter
  that contains the terms `password` or `secret`. The match is
  case sensitive.

  Phoenix's default is `["password"]`.

  Phoenix can filter all parameters by default and selectively keep
  parameters. This can be configured like so:

      config :phoenix, :filter_parameters, {:keep, ["id", "order"]}

  With the configuration above, Phoenix will filter all parameters,
  except those that match exactly `id` or `order`. If a kept parameter
  matches, all parameters nested under that one will also be kept.
  """
  require Logger
  import Phoenix.Controller

  alias Phoenix.Socket


  def phoenix_controller_call(:start, _compile, %{log_level: false}), do: :ok
  def phoenix_controller_call(:start, %{module: module}, %{log_level: level, conn: conn}) do
    Logger.log level, fn ->
      controller = inspect(module)
      action = conn |> action_name() |> Atom.to_string()
      ["Processing with ", controller, ?., action, ?/, ?2, ?\n,
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

  def phoenix_channel_receive(:start, _compile, meta) do
    %{socket: socket, params: params, event: event} = meta
    log_receive(socket.topic, event, socket, params)
  end
  def phoenix_channel_receive(:stop, _compile, :ok), do: :ok

  @doc false
  def filter_values(values, params \\ Application.get_env(:phoenix, :filter_parameters))
  def filter_values(values, {:discard, params}), do: discard_values(values, params)
  def filter_values(values, {:keep, params}), do: keep_values(values, params)
  def filter_values(values, params), do: discard_values(values, params)

  defp discard_values(%{__struct__: mod} = struct, _params) when is_atom(mod) do
    struct
  end
  defp discard_values(%{} = map, params) do
    Enum.into map, %{}, fn {k, v} ->
      if is_binary(k) and String.contains?(k, params) do
        {k, "[FILTERED]"}
      else
        {k, discard_values(v, params)}
      end
    end
  end
  defp discard_values([_|_] = list, params) do
    Enum.map(list, &discard_values(&1, params))
  end
  defp discard_values(other, _params), do: other

  defp keep_values(%{__struct__: mod}, _params) when is_atom(mod), do: "[FILTERED]"
  defp keep_values(%{} = map, params) do
    Enum.into map, %{}, fn {k, v} ->
      if is_binary(k) and k in params do
        {k, discard_values(v, [])}
      else
        {k, keep_values(v, params)}
      end
    end
  end
  defp keep_values([_|_] = list, params) do
    Enum.map(list, &keep_values(&1, params))
  end
  defp keep_values(_other, _params), do: "[FILTERED]"

  defp params(%Plug.Conn.Unfetched{}), do: "[UNFETCHED]"
  defp params(params) do
    params
    |> filter_values()
    |> inspect()
  end

  defp log_receive("phoenix" <> _, _event, _socket, _params), do: :ok
  defp log_receive(topic, event, socket, params) do
    channel_log(:log_handle_in, socket, fn ->
      "INCOMING #{inspect event} on #{inspect topic} to #{inspect(socket.channel)}\n" <>
      "  Transport:  #{inspect socket.transport}\n" <>
      "  Parameters: #{inspect filter_values(params)}"
    end)
  end

  defp log_join("phoenix" <> _, _socket, _params), do: :ok
  defp log_join(topic, socket, params) do
    channel_log(:log_join, socket, fn ->
      "JOIN #{inspect topic} to #{inspect(socket.channel)}\n" <>
      "  Transport:  #{inspect socket.transport} (#{socket.vsn})\n" <>
      "  Serializer:  #{inspect socket.serializer}\n" <>
      "  Parameters: #{inspect filter_values(params)}"
    end)
  end

  defp channel_log(log_option, %Socket{private: private}, message_or_func) do
    case Map.fetch(private, log_option) do
      {:ok, false} -> :ok
      {:ok, level} -> Logger.log(level, message_or_func)
    end
    :ok
  end
end
