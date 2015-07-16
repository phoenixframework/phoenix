defmodule Phoenix.Socket.Helpers do
  # Module that generates the channel topic matches.
  @moduledoc false

  @doc """
  Receives the `@phoenix_channels` accumulated attribute and returns AST of
  `match_channel` definitions
  """
  def defchannels(channels, transports) do
    channels_ast = for {topic_pattern, module, opts} <- channels do
      transport_modules = for {name, {transport_mod, _}} <- transports,
                          name in opts[:via],
                          do: transport_mod
      topic_pattern
      |> to_topic_match
      |> defchannel(module, transport_modules)
    end

    quote do
      unquote(channels_ast)
      def channel_for_topic(_topic, _transport), do: nil
    end
  end

  defp to_topic_match(topic_pattern) do
    case String.split(topic_pattern, "*") do
      [prefix, ""] -> quote do: <<unquote(prefix) <> _rest>>
      [bare_topic] -> bare_topic
      _            -> raise ArgumentError, "channels using splat patterns must end with *"
    end
  end

  defp defchannel(topic_match, channel_module, transports) do
    quote do
      def channel_for_topic(unquote(topic_match), transport)
        when transport in unquote(transports) do

        unquote(channel_module)
      end
    end
  end
end
