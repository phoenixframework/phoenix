defmodule Phoenix.Controller.Pipeline do
  @moduledoc false

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Plug

      require Phoenix.Endpoint

      import Phoenix.Controller.Pipeline
      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile Phoenix.Controller.Pipeline
      @phoenix_log_level Keyword.get(opts, :log, :debug)

      @doc false
      def init(action) when is_atom(action) do
        action
      end

      @doc false
      def call(conn, action) do
        conn = update_in conn.private,
                 &(&1 |> Map.put(:phoenix_controller, __MODULE__)
                      |> Map.put(:phoenix_action, action))

        Phoenix.Endpoint.instrument conn, :phoenix_controller_call,
          %{conn: conn, log_level: @phoenix_log_level}, fn ->
          phoenix_controller_pipeline(conn, action)
        end
      end

      @doc false
      def action(%{private: %{phoenix_action: action}} = conn, _options) do
        apply(__MODULE__, action, [conn, conn.params])
      end

      defoverridable [init: 1, call: 2, action: 2]
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    action = {:action, [], true}
    plugs  = [action|Module.get_attribute(env.module, :plugs)]
    {conn, body} = Plug.Builder.compile(env, plugs, log_on_halt: :debug)

    quote do
      defoverridable [action: 2]

      def action(conn, opts) do
        try do
          super(conn, opts)
        catch
          kind, reason ->
            Phoenix.Controller.Pipeline.__catch__(
              kind, reason, __MODULE__, conn.private.phoenix_action, System.stacktrace
            )
        end
      end

      defp phoenix_controller_pipeline(unquote(conn), var!(action)) do
        var!(conn) = unquote(conn)
        var!(controller) = __MODULE__
        _ = var!(conn)
        _ = var!(controller)
        _ = var!(action)

        unquote(body)
      end
    end
  end

  @doc false
  def __catch__(:error, :function_clause, controller, action,
                [{controller, action, [%Plug.Conn{} = conn | _], _loc} | _] = stack) do
    args = [controller: controller, action: action, params: conn.params]
    reraise Phoenix.ActionClauseError, args, stack
  end
  def __catch__(kind, reason, _controller, _action, stack) do
    :erlang.raise(kind, reason, stack)
  end

  @doc """
  Stores a plug to be executed as part of the plug pipeline.
  """
  defmacro plug(plug)

  defmacro plug({:when, _, [plug, guards]}), do:
    plug(plug, [], guards)

  defmacro plug(plug), do:
    plug(plug, [], true)

  @doc """
  Stores a plug with the given options to be executed as part of
  the plug pipeline.
  """
  defmacro plug(plug, opts)

  defmacro plug(plug, {:when, _, [opts, guards]}), do:
    plug(plug, opts, guards)

  defmacro plug(plug, opts), do:
    plug(plug, opts, true)

  defp plug(plug, opts, guards) do
    quote do
      @plugs {unquote(plug), unquote(opts), unquote(Macro.escape(guards))}
    end
  end
end
