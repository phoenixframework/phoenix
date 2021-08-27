defmodule Phoenix.Controller.Pipeline do
  @moduledoc false

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour Plug

      require Phoenix.Endpoint
      import Phoenix.Controller.Pipeline

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile Phoenix.Controller.Pipeline
      @phoenix_fallback :unregistered

      @doc false
      def init(opts), do: opts

      @doc false
      def call(conn, action) when is_atom(action) do
        conn
        |> merge_private(
          phoenix_controller: __MODULE__,
          phoenix_action: action
        )
        |> phoenix_controller_pipeline(action)
      end

      @doc false
      def action(%Plug.Conn{private: %{phoenix_action: action}} = conn, _options) do
        apply(__MODULE__, action, [conn, conn.params])
      end

      defoverridable init: 1, call: 2, action: 2
    end
  end

  @doc false
  def __action_fallback__(plug, caller) do
    plug = Macro.expand(plug, %{caller | function: {:init, 1}})
    quote bind_quoted: [plug: plug] do
      @phoenix_fallback Phoenix.Controller.Pipeline.validate_fallback(
                          plug,
                          __MODULE__,
                          Module.get_attribute(__MODULE__, :phoenix_fallback)
                        )
    end
  end

  @doc false
  def validate_fallback(plug, module, fallback) do
    cond do
      fallback == nil ->
        raise """
        action_fallback can only be called when using Phoenix.Controller.
        Add `use Phoenix.Controller` to #{inspect(module)}
        """

      fallback != :unregistered ->
        raise "action_fallback can only be called a single time per controller."

      not is_atom(plug) ->
        raise ArgumentError,
              "expected action_fallback to be a module or function plug, got #{inspect(plug)}"

      fallback == :unregistered ->
        case Atom.to_charlist(plug) do
          ~c"Elixir." ++ _ -> {:module, plug}
          _ -> {:function, plug}
        end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    action = {:action, [], true}
    plugs = [action | Module.get_attribute(env.module, :plugs)]

    {conn, body} =
      Plug.Builder.compile(env, plugs,
        log_on_halt: :debug,
        init_mode: Phoenix.plug_init_mode()
      )

    fallback_ast =
      env.module
      |> Module.get_attribute(:phoenix_fallback)
      |> build_fallback()

    quote do
      defoverridable action: 2

      def action(var!(conn_before), opts) do
        try do
          var!(conn_after) = super(var!(conn_before), opts)
          unquote(fallback_ast)
        catch
          :error, reason ->
            Phoenix.Controller.Pipeline.__catch__(
              var!(conn_before),
              reason,
              __MODULE__,
              var!(conn_before).private.phoenix_action,
              __STACKTRACE__
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

  defp build_fallback(:unregistered) do
    quote do: var!(conn_after)
  end

  defp build_fallback({:module, plug}) do
    quote bind_quoted: binding() do
      case var!(conn_after) do
        %Plug.Conn{} = conn_after -> conn_after
        val -> plug.call(var!(conn_before), plug.init(val))
      end
    end
  end

  defp build_fallback({:function, plug}) do
    quote do
      case var!(conn_after) do
        %Plug.Conn{} = conn_after -> conn_after
        val -> unquote(plug)(var!(conn_before), val)
      end
    end
  end

  @doc false
  def __catch__(
        %Plug.Conn{},
        :function_clause,
        controller,
        action,
        [{controller, action, [%Plug.Conn{} | _] = action_args, _loc} | _] = stack
      ) do
    args = [module: controller, function: action, arity: length(action_args), args: action_args]
    reraise Phoenix.ActionClauseError, args, stack
  end

  def __catch__(%Plug.Conn{} = conn, reason, _controller, _action, stack) do
    Plug.Conn.WrapperError.reraise(conn, :error, reason, stack)
  end

  @doc """
  Stores a plug to be executed as part of the plug pipeline.
  """
  defmacro plug(plug)

  defmacro plug({:when, _, [plug, guards]}), do: plug(plug, [], guards, __CALLER__)

  defmacro plug(plug), do: plug(plug, [], true, __CALLER__)

  @doc """
  Stores a plug with the given options to be executed as part of
  the plug pipeline.
  """
  defmacro plug(plug, opts)

  defmacro plug(plug, {:when, _, [opts, guards]}), do: plug(plug, opts, guards, __CALLER__)

  defmacro plug(plug, opts), do: plug(plug, opts, true, __CALLER__)

  defp plug(plug, opts, guards, caller) do
    runtime? = Phoenix.plug_init_mode() == :runtime

    plug =
      if runtime? do
        expand_alias(plug, caller)
      else
        plug
      end

    opts =
      if runtime? and Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, caller))
      else
        opts
      end

    quote do
      @plugs {unquote(plug), unquote(opts), unquote(escape_guards(guards))}
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:init, 1}})

  defp expand_alias(other, _env), do: other

  defp escape_guards({pre_expanded, _, [_ | _]} = node)
       when pre_expanded in [:@, :__aliases__],
       do: node

  defp escape_guards({left, meta, right}),
    do: {:{}, [], [escape_guards(left), meta, escape_guards(right)]}

  defp escape_guards({left, right}),
    do: {escape_guards(left), escape_guards(right)}

  defp escape_guards([_ | _] = list),
    do: Enum.map(list, &escape_guards/1)

  defp escape_guards(node),
    do: node
end
