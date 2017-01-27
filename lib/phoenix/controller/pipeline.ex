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
      @phoenix_fallback nil

      @doc false
      def init(opts), do: opts

      @doc false
      def call(conn, action) when is_atom(action) do
        conn = update_in conn.private,
                 &(&1 |> Map.put(:phoenix_controller, __MODULE__)
                      |> Map.put(:phoenix_action, action))

        Phoenix.Endpoint.instrument conn, :phoenix_controller_call,
          %{conn: conn, log_level: @phoenix_log_level}, fn ->
          phoenix_controller_pipeline(conn, action)
        end
      end

      @doc false
      def action(%Plug.Conn{private: %{phoenix_action: action}} = conn, _options) do
        apply(__MODULE__, action, [conn, conn.params])
      end

      defoverridable [init: 1, call: 2, action: 2]
    end
  end

  @doc """
  Registers the plug to call as a fallback to the controller action.

  A fallback plug is useful to translate common domain data structures
  into a valid `%Plug.Conn{}` response. If the controller action fails to
  return a `%Plug.Conn{}`, the provided plug will be called and receive
  the controller's `%Plug.Conn{}` as it was before the action was invoked
  along with the value returned from the controller action.

  ## Examples

      defmodule MyController do
        use Phoenix.Controller

        action_fallback MyFallbackController

        def show(conn, %{"id" => id}, current_user) do
          with {:ok, post} <- Blog.fetch_post(post),
               :ok <- Authorizer.authorize(current_user, :view, post) do

            render(conn, "show.json", post: post)
          end
        end
      end

  In the above exmaple, `with` is used to match only a successful
  post fetch, followed by valid authorization for the current user.
  If in the event either of those fail to match, `with` will not invoke
  the render block and instead returned the unmatched value. In this case,
  imagine `Blog.fetch_post/2` returned `{:error, :not_found}` or
  `Authorizer.authorize/3` returned `{:error, :unauthorized}`. For cases
  where these datastructures serve as return values across multiple
  boundaries in our domain, a single fallback module can be used to
  translate the value into a valid response. For example, you could
  write the following fallback controller to handle the above values:

      defmodule MyFallbackController do
        use Phoenix.Controller

        def call(conn, {:error, :not_found}) do
          conn
          |> put_status(:not_found)
          |> render(MyErrorView, :"404")
        end

        def call(conn, {:error, :unauthorized}) do
          conn
          |> put_status(403)
          |> render(MyErrorView, :"403")
        end
      end
  """
  defmacro action_fallback(plug) do
    quote bind_quoted: [plug: plug] do
      if is_atom(plug) do
        @phoenix_fallback plug
      else
        raise ArgumentError, "expected action_fallback to be a module, got #{inspect plug}"
      end
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
          conn
          |> super(opts)
          |> Phoenix.Controller.Pipeline.__fallback__(conn, @phoenix_fallback)
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
  def __fallback__(%Plug.Conn{} = conn_after, %Plug.Conn{} = _conn_before, _plug) do
    conn_after
  end
  def __fallback__(value_after, %Plug.Conn{} = _conn_before, nil) do
    value_after
  end
  def __fallback__(value_after, %Plug.Conn{} = conn_before, plug) do
    plug.call(conn_before, plug.init(value_after))
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
