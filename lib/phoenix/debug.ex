defmodule Phoenix.Debug do
  @moduledoc """
  Functions for runtime introspection and debugging of Phoenix applications.

  This module provides utilities for inspecting and debugging Phoenix applications.
  At the moment, it only includes functions related to `Phoenix.Socket` and `Phoenix.Channel`
  processes.

  It allows you to:

    * List all currently connected `Phoenix.Socket` transport processes.
    * List all channels for a given `Phoenix.Socket` process.
    * Get the socket of a channel process.
    * Check if a process is a `Phoenix.Socket` or `Phoenix.Channel`.

  """

  @doc """
  Returns a list of all currently connected `Phoenix.Socket` transport processes.

  Note that custom sockets implementing the `Phoenix.Socket.Transport` behaviour
  are not listed.

  Each process corresponds to one connection that can have multiple channels.

  For example, when using Phoenix LiveView, the browser establishes a socket
  connection when initially navigating to the page, and each live navigation
  retains the same socket connection. Nested LiveViews also share the same
  connection, each being a different channel. See `Phoenix.Debug.channels/1`.

  ## Examples

      iex> Phoenix.Debug.list_sockets()
      [%{pid: #PID<0.123.0>, module: Phoenix.LiveView.Socket, id: nil}]

  """
  def list_sockets do
    for pid <- Process.list(), dict = socket_process_dict(pid), not is_nil(dict) do
      {Phoenix.Socket, mod, id} = keyfind(dict, :"$process_label")
      %{pid: pid, module: mod, id: id}
    end
  end

  defp keyfind(list, key) do
    case List.keyfind(list, key, 0) do
      {^key, value} -> value
      _ -> nil
    end
  end

  defp socket_process_dict(pid) do
    # Phoenix.Socket sets the "$process_label" to {Phoenix.Socket, handler_module, id}
    with info when is_list(info) <- Process.info(pid, [:dictionary]),
         dictionary when not is_nil(dictionary) <- keyfind(info, :dictionary),
         label when not is_nil(label) <- keyfind(dictionary, :"$process_label"),
         {Phoenix.Socket, mod, id} when is_atom(mod) and (is_binary(id) or is_nil(id)) <- label do
      dictionary
    else
      _ -> nil
    end
  end

  @doc """
  Returns true if the given pid is a `Phoenix.Socket` transport process.

  It returns `false` for custom sockets implementing the `Phoenix.Socket.Transport` behaviour.

  ## Examples

      iex> Phoenix.Debug.list_sockets() |> Enum.at(0) |> Map.fetch!(:pid) |> socket_process?()
      true

      iex> socket_process?(pid(0,456,0))
      false

  """
  def socket_process?(pid) do
    not is_nil(socket_process_dict(pid))
  end

  @doc """
  Checks if the given pid is a `Phoenix.Channel` process.

  Note: this function returns false for [custom channels](https://hexdocs.pm/phoenix/Phoenix.Socket.html#module-custom-channels).
  """
  def channel_process?(pid) do
    # Phoenix.Channel sets the "$process_label" to {Phoenix.Socket, handler_module, id}
    with info when is_list(info) <- Process.info(pid, [:dictionary]),
         dictionary when not is_nil(dictionary) <- keyfind(info, :dictionary),
         label when not is_nil(label) <- keyfind(dictionary, :"$process_label"),
         {Phoenix.Channel, mod, topic} when is_atom(mod) and is_binary(topic) <- label do
      true
    else
      _ -> false
    end
  end

  @doc """
  Returns a list of all currently connected channels for the given `Phoenix.Socket` pid.

  Each channel is represented as a map with the following keys:

    - `:pid` - the pid of the channel process
    - `:status` - the status of the channel
    - `:topic` - the topic of the channel

  Note that this list also contains [custom channels](https://hexdocs.pm/phoenix/Phoenix.Socket.html#module-custom-channels)
  like LiveViews. You can check if a channel is a custom channel by using the `channel?/1`
  function, which returns `false` for custom channels.

  ## Examples

      iex> pid = Phoenix.Debug.list_sockets() |> Enum.at(0) |> Map.fetch!(:pid)
      iex> Phoenix.Debug.list_channels(pid)
      {:ok,
       [
         %{pid: #PID<0.1702.0>, status: :joined, topic: "lv:phx-GDp9a9UZPiTxcgnE"},
         %{pid: #PID<0.1727.0>, status: :joined, topic: "lv:sidebar"}
       ]}

      iex> Phoenix.Debug.list_channels(pid(0,456,0))
      {:error, :not_alive}

  """
  def list_channels(socket_pid) do
    ref = make_ref()

    if Process.alive?(socket_pid) and socket_process?(socket_pid) do
      send(socket_pid, {:debug_channels, ref, self()})

      receive do
        {:debug_channels, ^ref, channels} ->
          {:ok, channels}
      after
        5_000 -> {:error, :timeout}
      end
    else
      {:error, :not_alive}
    end
  end

  @doc """
  Returns the socket of the channel process.

  Note: this only works for channels defined with `use Phoenix.Channel`.
  For LiveViews, use the functions defined in `Phoenix.LiveView.Debug` instead.

  ## Examples

      iex> pid = Phoenix.Debug.list_sockets() |> Enum.at(0) |> Map.fetch!(:pid)
      iex> {:ok, channels} = Phoenix.Debug.list_channels(pid)
      iex> channels |> Enum.at(0) |> Map.fetch!(:pid) |> socket()
      {:ok, %Phoenix.Socket{...}}

      iex> socket(pid(0,456,0))
      {:error, :not_alive_or_not_a_channel}

  """
  def socket(channel_pid) do
    if channel_process?(channel_pid) do
      {:ok, Phoenix.Channel.Server.socket(channel_pid)}
    else
      {:error, :not_alive_or_not_a_channel}
    end
  catch
    :exit, _ -> {:error, :not_alive_or_not_a_channel}
  end
end
