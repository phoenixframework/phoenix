defmodule Phoenix.Channel.Supervisor do

  @moduledoc false

  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_child(%Phoenix.Socket{} = socket, auth_payload) do
    Supervisor.start_child(__MODULE__, [socket, auth_payload])
  end

  def terminate_child(child) do
    Supervisor.terminate_child(__MODULE__, child)
  end

  def init(:ok) do
    children = [
      worker(Phoenix.Channel.Server, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
