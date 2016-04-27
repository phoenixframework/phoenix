defmodule Phoenix.Controller.Pipeline do
  @moduledoc """
  This module implements the controller pipeline responsible for handling requests.

  ## The pipeline

  The goal of a controller is to receive a request and invoke the desired
  action. The whole flow of the controller is managed by a single pipeline:

      defmodule UserController do
        use Phoenix.Controller
        require Logger

        plug :log_message, "before action"

        def show(conn, _params) do
          Logger.debug "show/2"
          send_resp(conn, 200, "OK")
        end

        defp log_message(conn, msg) do
          Logger.debug msg
          conn
        end
      end

  When invoked, this pipeline will print:

      before action
      show/2

  As any other Plug pipeline, we can halt at any step by calling
  `Plug.Conn.halt/1` (which is by default imported into controllers).
  If we change `log_message/2` to:

      def log_message(conn, msg) do
        Logger.debug msg
        halt(conn)
      end

  it will print only:

      before action

  As the rest of the pipeline (the action and the after action plug)
  will never be invoked.

  ## Guards

  `plug/2` supports guards, allowing a developer to configure a plug to only
  run in some particular action:

      plug :log_message, "before show and edit" when action in [:show, :edit]
      plug :log_message, "before all but index" when not action in [:index]

  The first plug will run only when action is show or edit.
  The second plug will always run, except for the index action.

  Those guards work like regular Elixir guards and the only variables accessible
  in the guard are `conn`, the `action` as an atom and the `controller` as an
  alias.

  ## Controllers are plugs

  Like routers, controllers are plugs, but they are wired to dispatch
  to a particular function which is called an action.

  For example, the route:

      get "/users/:id", UserController, :show

  will invoke `UserController` as a plug:

      UserController.call(conn, :show)

  which will trigger the plug pipeline and which will eventually
  invoke the inner action plug that dispatches to the `show/2`
  function in the `UserController`.

  As controllers are plugs, they implement both `init/1` and
  `call/2`, and it also provides a function named `action/2`
  which is responsible for dispatching the appropriate action
  after the plug stack (and is also overridable).
  """

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
                [{controller, action, [%Plug.Conn{} | _], _loc} | _] = stack) do
    args = [controller: controller, action: action]
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
