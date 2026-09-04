defmodule Phoenix.Channel.AdoptStandin do
  @moduledoc false

  # This module acts as a stand-in for an adopted channel process,
  # by linking to it.
  # It is registered in the socket's drainer, so an adopted channel
  # is drained when the server shuts down.

  use Task

  def start_link(pid) do
    Task.start_link(__MODULE__, :link, [pid])
  end

  def link(pid) do
    Process.link(pid)
    Process.sleep(:infinity)
  end
end
