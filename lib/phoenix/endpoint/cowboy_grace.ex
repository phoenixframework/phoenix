defmodule Phoenix.Endpoint.CowboyGrace do
  @moduledoc false

  @behaviour :cowboy_middleware
  use GenServer

  def start(sup, grace) do
    Supervisor.start_child(sup, child_spec(grace))
  end

  defp child_spec(grace) do
    Supervisor.Spec.worker(__MODULE__, [], [shutdown: grace])
  end

  def start_link() do
    GenServer.start_link(__MODULE__, self())
  end

  def execute(req, env) do
    receive do
      {:CLOSE, _, _} -> {:ok, :cowboy_req.set([connection: :close], req), env}
    after
      0              -> {:ok, req, env}
    end
  end

  def init(parent) do
    _ = Process.flag(:trap_exit, true)
    GenServer.cast(self(), {:get_supervisors, parent})
    {:ok, nil}
  end

  def handle_cast({:get_supervisors, parent}, nil) do
    {:noreply, get_supervisors(parent)}
  end

  def terminate(_, nil), do: :ok
  def terminate(reason, {acceptors_sup, conns_sup}) do
    :ok = Supervisor.stop(acceptors_sup)
    conns_sup
    |> close_connections(reason)
    |> await_down()
  end

  defp get_supervisors(parent) do
    children = Supervisor.which_children(parent)
    {_, conns_sup, _, _} = List.keyfind(children, :ranch_conns_sup, 0)
    {_, acceptors_sup, _, _} = List.keyfind(children, :ranch_acceptors_sup, 0)
    {acceptors_sup, conns_sup}
  end

  defp close_connections(conns_sup, reason) do
    children = Supervisor.which_children(conns_sup)
    for {_, conn, _, _} <- children, into: %{},
      do: close_and_monitor(conn, reason)
  end

  defp close_and_monitor(conn, reason) do
    send(conn, {:CLOSE, self(), reason})
    {Process.monitor(conn), conn}
  end

  defp await_down(monitors) when monitors == %{}, do: :ok
  defp await_down(monitors) do
    receive do
      {:DOWN, ref, _, _, _} ->
        monitors
        |> Map.delete(ref)
        |> await_down()
      _ ->
        await_down(monitors)
    end
  end
end
