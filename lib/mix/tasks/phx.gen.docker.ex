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

    * `rel/overlays/bin/migrate` - A server script for conveniently invoking
      the release system with environment variables to start the phoenix web server.

  The following standard files are also generated and match the standard
  `mix release.init` task:

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

    binding = [
      app_namespace: Mix.Phoenix.base(),
      otp_app: app
    ]

    Mix.Phoenix.copy_from(paths(), "priv/templates/phx.gen.docker", binding, [
      {:eex, "Dockerfile.eex", "Dockerfile"},
      {:eex, "dockerignore.eex", ".dockerignore"},
      {:eex, "release.ex", Mix.Phoenix.context_lib_path(app, "release.ex")}
    ])

    Mix.Phoenix.copy_from(paths(), "priv/templates/phx.gen.docker/rel", binding, [
      {:eex, "env.bat.eex", "rel/env.bat.eex"},
      {:eex, "env.sh.eex", "rel/env.sh.eex"},
      {:eex, "remote.vm.args.eex", "rel/remote.vm.args.eex"},
      {:eex, "vm.args.eex", "rel/vm.args.eex"},
      {:eex, "migrate.sh.eex", "rel/overlays/bin/migrate"},
      {:eex, "server.sh.eex", "rel/overlays/bin/server"}
    ])
    File.chmod!("rel/overlays/bin/migrate", 0o700)
    File.chmod!("rel/overlays/bin/server", 0o700)

    Mix.shell().info("""

    Your application is ready to be deployed in a release!

        # To start your system
        _build/dev/rel/live_beats/bin/live_beats start

        # To start your system with the Phoenix server running
        _build/dev/rel/live_beats/bin/server

        # To run migrations
        _build/dev/rel/live_beats/bin/migrate

    Once the release is running:

        # To connect to it remotely
        _build/dev/rel/live_beats/bin/live_beats remote

        # To stop it gracefully (you may also send SIGINT/SIGTERM)
        _build/dev/rel/live_beats/bin/live_beats stop

    To list all commands:

        _build/dev/rel/live_beats/bin/live_beats
    """)
  end

  defp paths do
    [".", :phoenix]
  end
end
