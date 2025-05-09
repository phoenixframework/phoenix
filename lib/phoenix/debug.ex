defmodule Phoenix.Debug do
  @moduledoc """
  Functions for runtime introspection and debugging of Phoenix applications.

  TODO
  """

  @doc """
  Returns a list of all currently connected socket processes.

  Each process corresponds to one connection that can have multiple channels.

  For example, when using Phoenix LiveView, the browser establishes a socket
  connection when initially navigating to the page, and each live navigation
  retains the same socket connection. Nested LiveViews also share the same
  connection, each being a different channel. See `Phoenix.Debug.channels/1`.

  ## Examples

      iex> Phoenix.Debug.list_sockets()
      [#PID<0.123.0>]

  """
  def list_sockets do
    for pid <- Process.list(), socket?(pid) do
      pid
    end
  end

  @doc """
  Returns true if the given pid is a LiveView process.

  ## Examples

      iex> Phoenix.Debug.list_sockets() |> Enum.at(0) |> socket?()
      true

      iex> socket?(pid(0,456,0))
      false

  """
  def socket?(pid) do
    # Sockets set the "$process_label" to {Phoenix.Socket, handler_module, id}
    with info when is_list(info) <- Process.info(pid, [:dictionary]),
         {:dictionary, dictionary} <- List.keyfind(info, :dictionary, 0),
         {:"$process_label", label} <- List.keyfind(dictionary, :"$process_label", 0),
         {Phoenix.Socket, mod, id} when is_atom(mod) and (is_binary(id) or is_nil(id)) <- label do
      true
    else
      _ -> false
    end
  end

  @doc """
  Returns a list of all currently connected channels for the given socket pid.

  ## Examples

      iex> Phoenix.Debug.list_sockets |> Enum.at(0) |> Phoenix.Debug.channels()
      {:ok,
       [
         %{pid: #PID<0.1702.0>, status: :joined, topic: "lv:phx-GDp9a9UZPiTxcgnE"},
         %{pid: #PID<0.1727.0>, status: :joined, topic: "lv:sidebar"}
       ]}

      iex> Phoenix.Debug.channels(pid(0,456,0))
      {:error, :not_alive}

  """
  def channels(socket_pid) do
    ref = make_ref()

    if Process.alive?(socket_pid) do
      send(socket_pid, {:debug_channels, ref, self()})

      receive do
        {:debug_channels, ^ref, channels} -> {:ok, channels}
      after
        5_000 -> {:error, :timeout}
      end
    else
      {:error, :not_alive}
    end
  end
end
