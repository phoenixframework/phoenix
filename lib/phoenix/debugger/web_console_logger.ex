defmodule Phoenix.Debugger.WebConsoleLogger do
  @behaviour :gen_event

  @registry Phoenix.Debugger.WebConsoleLoggerRegistry

  def subscribe(endpoint) do
    {:ok, _} = Registry.register(@registry, endpoint, [])
    :ok
  end

  @impl true
  def init({__MODULE__, opts}) when is_list(opts) do
    {:ok, %{endpoint: Keyword.fetch!(opts, :endpoint)}}
  end

  @impl true
  def handle_event({level, _gl, {Logger, msg, ts, meta}}, state) do
    Registry.dispatch(@registry, state.endpoint, fn entries ->
      for {pid, _} <- entries, do: send(pid, {__MODULE__, level, msg, ts, meta})
    end)
    {:ok, state}
  end

  @impl true
  def handle_event(_, state) do
    {:ok, state}
  end

  @impl true
  def handle_call(_, state) do
    {:ok, :ok, state}
  end

  @impl true
  def handle_info(_, state) do
    {:ok, state}
  end

  @impl true
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
