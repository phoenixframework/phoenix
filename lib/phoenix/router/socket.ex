# TODO: Remove in 0.7.0
defmodule Phoenix.Router.Socket do
  alias Phoenix.Router.Scope

  defmacro __using__(options) do
    mount = Dict.fetch! options, :mount

    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :channels, accumulate: true)
      get unquote(mount), Phoenix.Transports.WebSocket, :upgrade_conn
      get unquote(mount <> "/poll"), Phoenix.Transports.LongPoller, :poll
      post unquote(mount <> "/poll"), Phoenix.Transports.LongPoller, :open
      put unquote(mount <> "/poll"), Phoenix.Transports.LongPoller, :publish
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    channels = defchannels(Module.get_attribute(env.module, :channels))
  end

  def defchannels(channels) do
    for {pattern, module, opts} <- channels do
      [root | _rest] = String.split(pattern, "*")

      quote do
        def match_channel(socket, :incoming, <<unquote(root) <> _rest>>, "join", msg) do
          apply(unquote(module), :join, [socket, socket.channel, msg])
        end
        def match_channel(socket, :incoming, <<unquote(root) <> _rest>>, "leave", msg) do
          apply(unquote(module), :leave, [socket, msg])
        end
        def match_channel(socket, :incoming, <<unquote(root) <> _rest>>, event, msg) do
          apply(unquote(module), :incoming, [socket, event, msg])
        end
        def match_channel(socket, :outgoing, <<unquote(root) <> _rest>>, event, msg) do
          apply(unquote(module), :outgoing, [socket, event, msg])
        end
      end
    end
  end

  defmacro channel(pattern, module, opts \\ []) do
    quote bind_quoted: binding do
      @channels {pattern, module, opts}
    end
  end
end
