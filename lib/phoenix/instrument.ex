defmodule Phoenix.Instrument do
  @doc false
  defmacro __using__(_opts) do
    quote unquote: false do
      # The `otp_app` variable is set by Phoenix.Endpoint.
      # TODO: maybe it's better to make Phoenix endpoints export __otp_app__()
      # or something similar?
      config = Application.get_env(var!(otp_app), __MODULE__, [])

      instrumenters = config[:instrumentation] || []

      unless is_list(instrumenters) and Enum.all?(instrumenters, &is_atom/1) do
        raise ":instrumentation must be a list of instrumenter modules"
      end

      instrumenter_and_events =
        (for inst <- instrumenters,
             {event, _arity} <- inst.__info__(:functions),
             do: {inst, event}) |> Macro.escape()

      @doc """
      Instruments the given block.

      `event` has to be a compile-time atom (otherwise, an `ArgumentError`
      exception will be raised).

      ## Examples

          instrument :render_view, [view: "index.html"] do
            render conn, "index.html"
          end

      """
      defmacro instrument(event, meta, do: block) do
        event = Macro.expand(event, __ENV__)

        unless is_atom(event) do
          raise ArgumentError, "the event passed to instrument/3 must be an atom"
        end

        interested_modules = interested_modules(unquote(instrumenter_and_events), event)

        if interested_modules != [] do
          quote do
            unquote(start_measure_code())
            unquote(start_measurements_code(interested_modules, event, meta))
            try do
              unquote(block)
            after
              unquote(stop_measure_code())
              unquote(stop_measurements_code(interested_modules, event, meta))
            end
          end
        end
      end

      # Returns the modules interested in the given `event`.
      # `instrumenters_and_events` is a list of `{instrumenter, event}` tuples.
      defp interested_modules(instrumenters_and_events, event) do
        for {inst, e} <- instrumenters_and_events, e == event, do: inst
      end

      defp start_measure_code() do
        quote do
          var!(start_measure, Phoenix.Instrument) = :os.timestamp()
        end
      end

      defp stop_measure_code() do
        quote do
          var!(duration, Phoenix.Instrument) =
            :timer.now_diff(:os.timestamp(), var!(start_measure, Phoenix.Instrument))
        end
      end

      defp start_measurements_code(interested_modules, event, meta) do
        for mod <- interested_modules do
          quote do
            unquote(start_callback_result_var(mod)) =
              unquote(mod).unquote(event)(:start, __ENV__, unquote(meta))
          end
        end
      end

      defp stop_measurements_code(interested_modules, event, meta) do
        for mod <- interested_modules do
          quote do
            unquote(mod).unquote(event)(:stop,
                                        var!(duration, Phoenix.Instrument),
                                        unquote(start_callback_result_var(mod)))
          end
        end
      end

      # Returns the AST of the variable used to store the result of the start
      # callback (for a given event) of the `instrumenter` module.
      #
      #     unquote(start_callback_result_var(inst)) = ...
      #
      defp start_callback_result_var(instrumenter) when is_atom(instrumenter) do
        instrumenter                          # MyInst
        |> Atom.to_string()                   # "MyInst"
        |> (fn inst -> "res_" <> inst end).() # "res_MyInst"
        |> String.to_atom()                   # :res_MyInst
        |> Macro.var(Phoenix.Instrument)      # variabilized!
      end
    end
  end
end
