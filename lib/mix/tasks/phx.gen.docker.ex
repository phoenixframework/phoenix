defmodule Mix.Tasks.Phx.Gen.Docker do
  @shortdoc "Generates a Dockerfile and release files for docker-based deployments"

  @moduledoc """
  Generates a Dockerfile and initializes a release for docker-baed deployments.

  The following files are created:

    * `Dockerfile` - The Dockerfile for use in any standar docker deployment

    * `.dockerignore` - A docker ignore file with standard elixir defaults

    * `lib/app_name/release.exs` - A release module containing tasks for running
      migrations inside a release

  The following release files are also generated. Note, the `rel/overlays` directory
  is copied into the release build by default when running `mix release`:

    * `rel/overlays/bin/migrate` - A migrate script for conveniently invoking
      the release system migrations.

    * `rel/overlays/bin/server` - A server script for conveniently invoking
      the release system with environment variables to start the phoenix web server.

  The following standard files are also generated by `mix release.init` if no
  `rel` directory exists:

    * `rel/env.bat.eex`
    * `rel/env.sh.eex`
    * `rel/remote.vm.args.eex`
    * `rel/vm.args.eex`
    * `rel/vm.args.eex`

  See the `Mix.Release` docs for more details.
  """

  use Mix.Task

  @doc false
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix phx.gen.docker is not supported in umbrella applications")
    end

    app = Mix.Phoenix.otp_app()
    app_namespace = Mix.Phoenix.base()

    binding = [
      app_namespace: app_namespace,
      otp_app: app
    ]

    unless File.exists?("rel") do
      Mix.Task.run("release.init")
    end

    Mix.Phoenix.copy_from(paths(), "priv/templates/phx.gen.docker/rel", binding, [
      {:eex, "migrate.sh.eex", "rel/overlays/bin/migrate"},
      {:eex, "server.sh.eex", "rel/overlays/bin/server"}
    ])

    Mix.Phoenix.copy_from(paths(), "priv/templates/phx.gen.docker", binding, [
      {:eex, "Dockerfile.eex", "Dockerfile"},
      {:eex, "dockerignore.eex", ".dockerignore"},
      {:eex, "release.ex", Mix.Phoenix.context_lib_path(app, "release.ex")}
    ])

    File.chmod!("rel/overlays/bin/migrate", 0o700)
    File.chmod!("rel/overlays/bin/server", 0o700)

    Mix.shell().info("""

    Your application is ready to be deployed in a release!

        # To start your system
        _build/dev/rel/#{app}/bin/#{app} start

        # To start your system with the Phoenix server running
        _build/dev/rel/#{app}/bin/server

        # To run migrations
        _build/dev/rel/#{app}/bin/migrate

    Once the release is running:

        # To connect to it remotely
        _build/dev/rel/#{app}/bin/#{app} remote

        # To stop it gracefully (you may also send SIGINT/SIGTERM)
        _build/dev/rel/#{app}/bin/#{app} stop

    To list all commands:

        _build/dev/rel/#{app}/bin/#{app}
    """)

    post_install_instructions("config/runtime.exs", ~r/ECTO_IPV6/, """
    [warn] Conditional IPV6 support missing from runtime configuration.

    Add the following to your config/runtime.exs:

        ipv6? = System.get_env("ECTO_IPV6") == "true"

        config :#{app}, #{app_namespace}.Repo,
          ...,
          socket_options: if(ipv6?, do: [:inet6], else: [])
    """)

    post_install_instructions("config/runtime.exs", ~r/PHX_SERVER/, """
    [warn] Conditional server startup is missing from runtime configuration.

    Add the following to your config/runtime.exs:

        server? = System.get_env("PHX_SERVER") == "true"

        config :#{app}, #{app_namespace}.Endpoint,
          ...,
          server: server?
    """)

    post_install_instructions("config/runtime.exs", ~r/PHX_HOST/, """
    [warn] Environment based URL export is missing from runtime configuration.

    Add the following to your config/runtime.exs:

        host = System.get_env("PHX_HOST") || "example.com"

        config :#{app}, #{app_namespace}.Endpoint,
          ...,
          url: [host: host, port: 80]
    """)
  end

  defp paths do
    [".", :phoenix]
  end

  defp post_install_instructions(path, matching, msg) do
    case File.read(path) do
      {:ok, content} ->
        unless content =~ matching, do: Mix.shell().info(msg)

      {:error, _} ->
        Mix.shell().info(msg)
    end
  end
end
