defmodule Mix.Tasks.Phx.Gen.Socket do
  @shortdoc "Generates a Phoenix socket handler"

  @moduledoc """
  Generates a Phoenix socket handler.

      mix phx.gen.socket User

  Accepts the module name for the socket

  The generated files will contain:

  For a regular application:

    * a socket in `lib/my_app_web/channels`
    * a socket test in `test/my_app_web/channels`

  For an umbrella application:

    * a socket in `apps/my_app_web/lib/app_name_web/channels`
    * a socket test in `apps/my_app_web/test/my_app_web/channels`

  """
  use Mix.Task

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.socket must be invoked from within your *_web application root directory"
      )
    end

    [socket_name] = validate_args!(args)

    context_app = Mix.Phoenix.context_app()
    web_prefix = Mix.Phoenix.web_path(context_app)
    binding = Mix.Phoenix.inflect(socket_name)

    binding =
      binding
      |> Keyword.put(:module, "#{binding[:web_module]}.#{binding[:scoped]}")
      |> Keyword.put(:endpoint_module, Module.concat([binding[:web_module], Endpoint]))
      |> Keyword.put(:web_prefix, web_prefix)

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

    After that you can define your `channel` topic in the newly created socket file.
    In order to create new channel files, you can use channel generator:

        mix phx.gen.channel Room

    For the front-end integration, you need to import the `#{binding[:path]}_socket.js`
    in your `app.js` file:

        import "./#{binding[:path]}_socket.js"
    """)
  end

  @spec raise_with_help() :: no_return()
  defp raise_with_help do
    Mix.raise("""
    mix phx.gen.socket expects just the module name:

        mix phx.gen.socket User

    """)
  end

  defp validate_args!(args) do
    unless length(args) == 1 do
      raise_with_help()
    end

    args
  end

  defp paths do
    [".", :phoenix]
  end
end
