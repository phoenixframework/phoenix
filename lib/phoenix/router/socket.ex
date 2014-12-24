# TODO: Remove in 0.7.0
defmodule Phoenix.Router.Socket do
  alias Phoenix.Router.Scope

  @transports [Phoenix.Transports.WebSocket, Phoenix.Transports.LongPoller]

  defmacro __using__(options) do
    mount = Dict.fetch! options, :mount

    quote do
      Module.register_attribute(__MODULE__, :channels, accumulate: true)
      import unquote(__MODULE__), only: [channel: 3, channel: 2]
      get unquote(mount), Phoenix.Transports.WebSocket, :upgrade_conn
      get unquote(mount <> "/poll"), Phoenix.Transports.LongPoller, :poll
      post unquote(mount <> "/poll"), Phoenix.Transports.LongPoller, :open
      put unquote(mount <> "/poll"), Phoenix.Transports.LongPoller, :publish
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    defchannels(Module.get_attribute(env.module, :channels))
  end

  def defchannels(channels) do
    channels_ast = for {topic_pattern, module, opts} <- channels do
      transports = opts[:via] || @transports
      [root | _rest] = String.split(topic_pattern, "*")

      quote do
        def match_channel(socket, :incoming, <<unquote(root) <> _rest>>, "join", msg_payload, transport)
          when transport in unquote(transports) do
          apply(unquote(module), :join, [socket, socket.topic, msg_payload])
        end
        def match_channel(socket, :incoming, <<unquote(root) <> _rest>>, "leave", msg_payload, transport)
          when transport in unquote(transports) do
          apply(unquote(module), :leave, [socket, msg_payload])
        end
        def match_channel(socket, :incoming, <<unquote(root) <> _rest>>, event, msg_payload, transport)
          when transport in unquote(transports) do
          apply(unquote(module), :incoming, [socket, event, msg_payload])
        end
        def match_channel(socket, :outgoing, <<unquote(root) <> _rest>>, event, msg_payload, _transport) do
          apply(unquote(module), :outgoing, [socket, event, msg_payload])
        end
      end
    end

    quote do
      unquote(channels_ast)
      def match_channel(socket, _direction, _channel, _event, _msg_payload, _transport) do
        {:error, socket, :badmatch}
      end
    end
  end

  defmacro channel(topic_pattern, module, opts \\ []) do
    quote bind_quoted: binding do
      if Scope.inside_scope?(__MODULE__) do
        raise """
        You are trying to call `channel` within a `scope` definition.
        Please move your channel definitions outside of any scope block.
        """
      end

      @channels {topic_pattern, module, opts}
    end
  end
end
