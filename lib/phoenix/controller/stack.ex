defmodule Phoenix.Controller.Stack do
  @moduledoc """
  This module implements the controller stack responsible for handling requests.

  In this documentation we will learn more about customizing the controller
  stack and how it works internally.

  ## The stack

  The goal of a controller is to receive a request and invoke the desired
  action. Phoenix provides two mechanisms to manipulate the connection
  before and after a request:

      defmodule UserController do
        use Phoenix.Controller
        require Logger

        before_action :log_message, "before action"
        after_action :log_message, "after action"

        def show(conn, _params) do
          Logger.debug "show/2"
          send_resp(conn, 200, "OK")
        end

        defp log_message(conn, msg) do
          Logger.debug msg
          conn
        end
      end

  When invoked, this stack will print:

      before action
      show/2
      after action

  As any other Plug stack, we can halt at any step by calling
  `Plug.Conn.halt/1` (which is by default imported into controllers).
  If we change log_message/2 to:

      def log_message(conn, msg) do
        Logger.debug msg
        halt(conn)
      end

  It will print only:

      before action

  As the rest of the stack (the action and the after action plug)
  will never be invoked.

  ## Guards

  Both `before_action/2` and `after_action/2` support guards, allowing
  a developer to configure a plug to only run in some particular action:

      before_action :log_message, "before action" when action in [:show, :edit]
      after_action :log_message, "after action" when not action in [:index]

  The first plug will run only when action is show and edit, while the second
  will always run except for the index action.

  Those guards work like regular Elixir guards and the only variables accessible
  in the guard are `conn`, the `action` as an atom and the `controller` as a
  module.

  ## Controllers are plugs

  Like routers, controllers are plugs, but they are wired to dispatch
  to a particular function which is called an action.

  For example, the route:

      get "/users/:id", UserController, :show

  will invoke `UserController` as a plug:

      UserController.call(conn, :show)

  which will trigger the plug stack and eventually invoke the
  `show/2` function in the `UserController`.

  As controllers are plugs, they implement both `init/1` and
  `call/2`, and it also provides a function named `action/2`
  which is responsible for dispatching the appropriate action
  in the middle of the plug stack (and is also overridable).
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
        var!(conn) = unquote(conn)
        var!(controller) = __MODULE__
        _ = var!(conn)
        _ = var!(controller)
        _ = var!(action)
        unquote(body)
      end
    end
  end

  @doc """
  Stores a plug to be executed before an action.
  """
  defmacro before_action(plug) do
    plug(:before_action, plug)
  end

  @doc """
  Stores a plug with the given options to be executed before an action.
  """
  defmacro before_action(plug, opts) do
    plug(:before_action, plug, opts)
  end

  @doc """
  Stores a plug to be executed after an action.

  `after_action` must be rarely used in practice. It is almost always
  better to use one of the hooks defined in `Plug.Conn` that perform
  some action when a response is sent.
  """
  defmacro after_action(plug) do
    plug(:after_action, plug)
  end

  @doc """
  Stores a plug with the given options to be executed after an action.
  """
  defmacro after_action(plug, opts) do
    plug(:after_action, plug, opts)
  end

  defp plug(kind, {:when, _, [plug, guards]}), do:
    plug(kind, plug, [], guards)

  defp plug(kind, plug), do:
    plug(kind, plug, [], true)

  defp plug(kind, plug, {:when, _, [opts, guards]}), do:
    plug(kind, plug, opts, guards)

  defp plug(kind, plug, opts), do:
    plug(kind, plug, opts, true)

  defp plug(kind, plug, opts, guards) do
    quote do
      Module.put_attribute(__MODULE__, unquote(kind),
                           {unquote(plug), unquote(opts), unquote(Macro.escape(guards))})
    end
  end
end
