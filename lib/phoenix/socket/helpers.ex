defmodule Phoenix.Socket.Helpers do
  # Module that generates the channel topic matches.
  @moduledoc false

  @doc """
  Registers the transport, with defaults and duplicate validation.
  """
  def register_transport(phoenix_transports, name, module, config) do
    merged_conf = case phoenix_transports[name] do
      nil -> Keyword.merge(module.default_config() , config)
      {dup_module, _} ->
        raise ArgumentError, """
        duplicate transports (`#{inspect dup_module}`, `#{inspect module}`) defined for `:#{name}`".
        Only a single transport adapter can be defined for a given name.
        """
    end

    Map.put(phoenix_transports, name, {module, merged_conf})
  end

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
