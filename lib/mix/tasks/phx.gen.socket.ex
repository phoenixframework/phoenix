defmodule Mix.Tasks.Phx.Gen.Socket do
  @shortdoc "Generates a Phoenix socket handler"

  @moduledoc """
  Generates a Phoenix socket handler.

      $ mix phx.gen.socket User

  Accepts the module name for the socket

  The generated files will contain:

  For a regular application:

    * a client in `assets/js`
    * a socket in `lib/my_app_web/channels`

  For an umbrella application:

    * a client in `apps/my_app_web/assets/js`
    * a socket in `apps/my_app_web/lib/app_name_web/channels`

  You can then generated channels with `mix phx.gen.channel`.
  """
  use Mix.Task

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.socket must be invoked from within your *_web application root directory"
      )
    end

    [socket_name, pre_existing_channel] = validate_args!(args)

    context_app = Mix.Phoenix.context_app()
    web_prefix = Mix.Phoenix.web_path(context_app)
    binding = Mix.Phoenix.inflect(socket_name)

    existing_channel =
      if pre_existing_channel do
        channel_binding = Mix.Phoenix.inflect(pre_existing_channel)

        Keyword.put(
          channel_binding,
          :module,
          "#{channel_binding[:web_module]}.#{channel_binding[:scoped]}"
        )
      end

    binding =
      binding
      |> Keyword.put(:module, "#{binding[:web_module]}.#{binding[:scoped]}")
      |> Keyword.put(:endpoint_module, Module.concat([binding[:web_module], Endpoint]))
      |> Keyword.put(:web_prefix, web_prefix)
      |> Keyword.put(:existing_channel, existing_channel)

    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "Socket")

    Mix.Phoenix.copy_from(paths(), "priv/templates/phx.gen.socket", binding, [
      {:eex, "socket.ex", Path.join(web_prefix, "channels/#{binding[:path]}_socket.ex")},
      {:eex, "socket.js", "assets/js/#{binding[:path]}_socket.js"}
    ])

    Mix.shell().info("""

    Add the socket handler to your `#{Mix.Phoenix.web_path(context_app, "endpoint.ex")}`, for example:

        socket "/socket", #{binding[:module]}Socket,
          websocket: true,
          longpoll: false

    For the front-end integration, you need to import the `#{binding[:path]}_socket.js`
    in your `assets/js/app.js` file:

        import "./#{binding[:path]}_socket.js"
    """)
  end

  @spec raise_with_help() :: no_return()
  defp raise_with_help do
    Mix.raise("""
    mix phx.gen.socket expects the module name:

        mix phx.gen.socket User

    """)
  end

  defp validate_args!([name, "--from-channel", pre_existing_channel]) do
    unless valid_name?(name) and valid_name?(pre_existing_channel) do
      raise_with_help()
    end

    [name, pre_existing_channel]
  end

  defp validate_args!([name]) do
    unless valid_name?(name) do
      raise_with_help()
    end

    [name, nil]
  end

  defp validate_args!(_), do: raise_with_help()

  defp valid_name?(name) do
    name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  defp paths do
    [".", :phoenix]
  end
end
