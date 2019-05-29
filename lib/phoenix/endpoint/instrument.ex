defmodule Phoenix.Endpoint.Instrument do
  @moduledoc false

  # This is the arity that event callbacks in the instrumenter modules must
  # have.
  @event_callback_arity 3

  @doc false
  def definstrument(otp_app, endpoint) do
    app_instrumenters = app_instrumenters(otp_app, endpoint)

    quote bind_quoted: [app_instrumenters: app_instrumenters] do
      require Logger

      @doc """
      Instruments the given function.

      `event` is the event identifier (usually an atom) that specifies which
      instrumenting function to call in the instrumenter modules. `runtime` is
      metadata to be associated with the event at runtime (e.g., the query being
      issued if the event to instrument is a DB query).

      ## Examples

          instrument :render_view, %{view: "index.html"}, fn ->
            render(conn, "index.html")
          end

      """
      defmacro instrument(event, runtime \\ Macro.escape(%{}), fun) do
        compile = Macro.escape(Phoenix.Endpoint.Instrument.strip_caller(__CALLER__))

        quote do
          unquote(__MODULE__).instrument(
            unquote(event),
            unquote(compile),
            unquote(runtime),
            unquote(fun)
          )
        end
      end

      # For each event in any of the instrumenters, we must generate a
      # clause of the `instrument/4` function. It'll look like this:
      #
      #   def instrument(:my_event, compile, runtime, fun) do
      #     res0 = Inst0.my_event(:start, compile, runtime)
      #     ...
      #
      #     start = :erlang.monotonic_time
      #     try do
      #       fun.()
      #     after
      #       diff = ...
      #       Inst0.my_event(:stop, diff, res0)
      #       ...
      #     end
      #   end
      #
      @doc false
      def instrument(event, compile, runtime, fun)

      for {event, instrumenters} <- app_instrumenters do
        def instrument(unquote(event), var!(compile), var!(runtime), fun)
            when is_map(var!(compile)) and is_map(var!(runtime)) and is_function(fun, 0) do
          unquote(Phoenix.Endpoint.Instrument.compile_start_callbacks(event, instrumenters))
          start = :erlang.monotonic_time
          try do
            fun.()
          after
            var!(diff) = :erlang.monotonic_time - start
            unquote(Phoenix.Endpoint.Instrument.compile_stop_callbacks(event, instrumenters))
          end
        end
      end

      # Catch-all clause
      def instrument(event, compile, runtime, fun)
          when is_atom(event) and is_map(compile) and is_map(runtime) and is_function(fun, 0) do
        fun.()
      end
    end
  end

  # Reads a list of the instrumenters from the config of `otp_app` and finds all
  # events in those instrumenters. The return value is a list of `{event,
  # instrumenters}` tuples, one for each event defined by any instrumenters
  # (with no duplicated events); `instrumenters` is the list of instrumenters
  # interested in `event`.
  defp app_instrumenters(otp_app, endpoint) do
    config        = Application.get_env(otp_app, endpoint, [])
    instrumenters = config[:instrumenters] || []

    unless is_list(instrumenters) and Enum.all?(instrumenters, &is_atom/1) do
      raise ":instrumenters must be a list of instrumenter modules"
    end

    events_to_instrumenters(instrumenters)
  end

  # Strips a `Macro.Env` struct, leaving only interesting compile-time metadata.
  @doc false
  @spec strip_caller(Macro.Env.t) :: %{}
  def strip_caller(%Macro.Env{module: mod, function: fun, file: file, line: line}) do
    caller = %{module: mod, function: form_fa(fun), file: file, line: line}

    if app = Application.get_env(:logger, :compile_time_application) do
       Map.put(caller, :application, app)
    else
      caller
    end
  end

  defp form_fa({name, arity}), do: Atom.to_string(name) <> "/" <> Integer.to_string(arity)
  defp form_fa(nil), do: nil

  # called by Phoenix.Endpoint.instrument/4, see docs there
  @doc false
  @spec extract_endpoint(Plug.Conn.t | Phoenix.Socket.t | module) :: module | nil
  def extract_endpoint(endpoint_or_conn_or_socket) do
    case endpoint_or_conn_or_socket do
      %Plug.Conn{private: %{phoenix_endpoint: endpoint}} -> endpoint
      %Phoenix.Socket{endpoint: endpoint} -> endpoint
      %{__struct__: struct} when struct in [Plug.Conn, Phoenix.Socket] -> nil
      endpoint -> endpoint
    end
  end

  # Returns the AST for all the calls to the "start event" callbacks in the given
  # list of `instrumenters`.
  # Each function call looks like this:
  #
  #     res0 = Instr0.my_event(:start, compile, runtime)
  #
  @doc false
  @spec compile_start_callbacks(term, [module]) :: Macro.t
  def compile_start_callbacks(event, instrumenters) do
    Enum.map Enum.with_index(instrumenters), fn {inst, index} ->
      error_prefix = "Instrumenter #{inspect inst}.#{event}/3 failed.\n"
      quote do
        unquote(build_result_variable(index)) =
          try do
            unquote(inst).unquote(event)(:start, var!(compile), var!(runtime))
          catch
            kind, error ->
              Logger.error [unquote(error_prefix), Exception.format(kind, error, System.stacktrace())]
          end
      end
    end
  end

  # Returns the AST for all the calls to the "stop event" callbacks in the given
  # list of `instrumenters`.
  # Each function call looks like this:
  #
  #     Instr0.my_event(:stop, diff, res0)
  #
  @doc false
  @spec compile_stop_callbacks(term, [module]) :: Macro.t
  def compile_stop_callbacks(event, instrumenters) do
    Enum.map Enum.with_index(instrumenters), fn {inst, index} ->
      error_prefix = "Instrumenter #{inspect inst}.#{event}/3 failed.\n"
      quote do
        try do
          unquote(inst).unquote(event)(:stop, var!(diff), unquote(build_result_variable(index)))
        catch
          kind, error ->
            Logger.error unquote(error_prefix) <> Exception.format(kind, error)
        end
      end
    end
  end

  # Takes a list of instrumenter modules and returns a list of `{event,
  # instrumenters}` tuples where each tuple represents an event and all the
  # modules interested in that event.
  defp events_to_instrumenters(instrumenters) do
    instrumenters                                              # [Ins1, Ins2, ...]
    |> instrumenters_and_events()                              # [{Ins1, e1}, {Ins2, e1}, ...]
    |> Enum.group_by(fn {_inst, e} -> e end)                   # %{e1 => [{Ins1, e1}, ...], ...}
    |> Enum.map(fn {e, insts} -> {e, strip_events(insts)} end) # [{e1, [Ins1, Ins2]}, ...]
  end

  defp instrumenters_and_events(instrumenters) do
    # We're only interested in functions (events) with the given arity.
    for inst <- instrumenters,
        {event, @event_callback_arity} <- inst.__info__(:functions),
        do: {inst, event}
  end

  defp strip_events(instrumenters) do
    for {inst, _evt} <- instrumenters, do: inst
  end

  defp build_result_variable(index) when is_integer(index) do
    "res#{index}" |> String.to_atom() |> Macro.var(nil)
  end
end
