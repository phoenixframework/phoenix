defmodule Phoenix.Controller.Stack do
  @moduledoc """
  Write docs.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour Plug

      import Phoenix.Controller.Stack
      Module.register_attribute(__MODULE__, :before_action, accumulate: true)
      Module.register_attribute(__MODULE__, :after_action, accumulate: true)
      @before_compile Phoenix.Controller.Stack

      def init(action) when is_atom(action) do
        action
      end

      def call(conn, action) do
        conn = update_in conn.private,
                 &(&1 |> Map.put(:phoenix_controller, __MODULE__)
                      |> Map.put(:phoenix_action, action))
        phoenix_controller_stack(conn, action)
      end

      def action(%{private: %{phoenix_action: action}} = conn, _options) do
        apply(__MODULE__, action, [conn, conn.params])
      end

      defoverridable [init: 1, call: 2, action: 2]
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    before_action = Module.get_attribute(env.module, :before_action)
    after_action  = Module.get_attribute(env.module, :after_action)
    plugs = after_action ++ [{:action, [], true}] ++ before_action
    {conn, body} = Plug.Builder.compile(plugs)
    quote do
      defp phoenix_controller_stack(unquote(conn), var!(action)) do
        var!(controller) = __MODULE__
        _ = var!(controller)
        _ = var!(action)
        unquote(body)
      end
    end
  end

  @doc """
  Stores a plug to be executed before the action.
  """
  defmacro before_action(plug, opts \\ []) do
    quote do
      @before_action {unquote(plug), unquote(opts), true}
    end
  end

  @doc """
  Stores a plug to be executed after the action.

  `after_action` must be rarely used in practice. It is almost always
  better to use one of the hooks defined in `Plug.Conn` that perform
  some action when a response is sent.
  """
  defmacro after_action(plug, opts \\ []) do
    quote do
      @after_action {unquote(plug), unquote(opts), true}
    end
  end
end
