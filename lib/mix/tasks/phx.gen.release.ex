defmodule Mix.Tasks.Phx.Gen.Release do
  @shortdoc "Generates release files and optional Dockerfile for release-based deployments"

  @moduledoc """
  Generates release files and optional Dockerfile for release-based deployments.

  The following release files are created:

    * `lib/app_name/release.ex` - A release module containing tasks for running
      migrations inside a release

    * `rel/overlays/bin/migrate` - A migrate script for conveniently invoking
      the release system migrations

    * `rel/overlays/bin/server` - A server script for conveniently invoking
      the release system with environment variables to start the phoenix web server

  Note, the `rel/overlays` directory is copied into the release build by default when
  running `mix release`.

  To skip generating the migration-related files, use the `--no-ecto` flag. To
  force these migration-related files to be generated, the use `--ecto` flag.

  ## Docker

  When the `--docker` flag is passed, the following docker files are generated:

    * `Dockerfile` - The Dockerfile for use in any standard docker deployment

    * `.dockerignore` - A docker ignore file with standard elixir defaults

  For extended release configuration, the `mix release.init` task can be used
  in addition to this task. See the `Mix.Release` docs for more details.
  """

  use Mix.Task

  require Logger

  @doc false
  def run(args) do
    opts = parse_args(args)

    if Mix.Project.umbrella?() do
      Mix.raise("""
      mix phx.gen.release is not supported in umbrella applications.

      Run this task in your web application instead.
      """)
    end

    app = Mix.Phoenix.otp_app()
    app_namespace = Mix.Phoenix.base()
    web_namespace = app_namespace |> Mix.Phoenix.web_module() |> inspect()

    binding = [
      app_namespace: app_namespace,
      otp_app: app,
      assets_dir_exists?: File.dir?("assets")
    ]

    Mix.Phoenix.copy_from(paths(), "priv/templates/phx.gen.release", binding, [
      {:eex, "rel/server.sh.eex", "rel/overlays/bin/server"},
      {:eex, "rel/server.bat.eex", "rel/overlays/bin/server.bat"}
    ])

    if opts.ecto do
      Mix.Phoenix.copy_from(paths(), "priv/templates/phx.gen.release", binding, [
        {:eex, "rel/migrate.sh.eex", "rel/overlays/bin/migrate"},
        {:eex, "rel/migrate.bat.eex", "rel/overlays/bin/migrate.bat"},
        {:eex, "release.ex", Mix.Phoenix.context_lib_path(app, "release.ex")}
      ])
    end

    if opts.docker do
      gen_docker(binding)
    end

    File.chmod!("rel/overlays/bin/server", 0o755)
    File.chmod!("rel/overlays/bin/server.bat", 0o755)

    if opts.ecto do
      File.chmod!("rel/overlays/bin/migrate", 0o755)
      File.chmod!("rel/overlays/bin/migrate.bat", 0o755)
    end

    Mix.shell().info("""

    Your application is ready to be deployed in a release!

    See https://hexdocs.pm/mix/Mix.Tasks.Release.html for more information about Elixir releases.
    #{if opts.docker, do: docker_instructions()}
    Here are some useful release commands you can run in any release environment:

        # To build a release
        mix release

        # To start your system with the Phoenix server running
        _build/dev/rel/#{app}/bin/server
    #{if opts.ecto, do: ecto_instructions(app)}
    Once the release is running you can connect to it remotely:

        _build/dev/rel/#{app}/bin/#{app} remote

    To list all commands:

        _build/dev/rel/#{app}/bin/#{app}
    """)

    if opts.ecto do
      post_install_instructions("config/runtime.exs", ~r/ECTO_IPV6/, """
      [warn] Conditional IPV6 support missing from runtime configuration.

      Add the following to your config/runtime.exs:

          maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

          config :#{app}, #{app_namespace}.Repo,
            ...,
            socket_options: maybe_ipv6
      """)
    end

    post_install_instructions("config/runtime.exs", ~r/PHX_SERVER/, """
    [warn] Conditional server startup is missing from runtime configuration.

    Add the following to the top of your config/runtime.exs:

        if System.get_env("PHX_SERVER") do
          config :#{app}, #{web_namespace}.Endpoint, server: true
        end
    """)

    post_install_instructions("config/runtime.exs", ~r/PHX_HOST/, """
    [warn] Environment based URL export is missing from runtime configuration.

    Add the following to your config/runtime.exs:

        host = System.get_env("PHX_HOST") || "example.com"

        config :#{app}, #{web_namespace}.Endpoint,
          ...,
          url: [host: host, port: 443]
    """)
  end

  defp parse_args(args) do
    args
    |> OptionParser.parse!(strict: [ecto: :boolean, docker: :boolean])
    |> elem(0)
    |> Keyword.put_new_lazy(:ecto, &ecto_sql_installed?/0)
    |> Keyword.put_new(:docker, false)
    |> Map.new()
  end

  defp ecto_instructions(app) do
    """

        # To run migrations
        _build/dev/rel/#{app}/bin/migrate
    """
  end

  defp docker_instructions do
    """

    Using the generated Dockerfile, your release will be bundled into
    a Docker image, ready for deployment on platforms that support Docker.

    For more information about deploying with Docker see
    https://hexdocs.pm/phoenix/releases.html#containers
    """
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

  defp ecto_sql_installed?, do: Mix.Project.deps_paths() |> Map.has_key?(:ecto_sql)

  @debian "bullseye"
  defp gen_docker(binding) do
    elixir_vsn =
      case Version.parse!(System.version()) do
        %{major: major, minor: minor, pre: ["dev"]} -> "#{major}.#{minor - 1}.0"
        _ -> System.version()
      end

    otp_vsn = otp_vsn()

    url =
      "https://hub.docker.com/v2/namespaces/hexpm/repositories/elixir/tags?name=#{elixir_vsn}-erlang-#{otp_vsn}-debian-#{@debian}-"

    debian_vsn =
      fetch_body!(url)
      |> Phoenix.json_library().decode!()
      |> Map.fetch!("results")
      |> Enum.find_value(:error, fn %{"name" => name} ->
        if String.ends_with?(name, "-slim") do
          %{"vsn" => vsn} = Regex.named_captures(~r/.*debian-#{@debian}-(?<vsn>.*)-slim/, name)
          {:ok, vsn}
        end
      end)

    case debian_vsn do
      {:ok, debian_vsn} ->
        binding =
          Keyword.merge(binding,
            debian: @debian,
            debian_vsn: debian_vsn,
            elixir_vsn: elixir_vsn,
            otp_vsn: otp_vsn
          )

        Mix.Phoenix.copy_from(paths(), "priv/templates/phx.gen.release", binding, [
          {:eex, "Dockerfile.eex", "Dockerfile"},
          {:eex, "dockerignore.eex", ".dockerignore"}
        ])

      :error ->
        raise "unable to fetch supported Docker image for Elixir #{elixir_vsn} and Erlang #{otp_vsn}"
    end
  end

  defp fetch_body!(url) do
    url = String.to_charlist(url)
    Logger.debug("Fetching latest image information from #{url}")

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = System.get_env("HTTP_PROXY") || System.get_env("http_proxy") do
      Logger.debug("Using HTTP_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:proxy, {{String.to_charlist(host), port}, []}}])
    end

    if proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy") do
      Logger.debug("Using HTTPS_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:https_proxy, {{String.to_charlist(host), port}, []}}])
    end

    # https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
    http_options = [
      ssl: [
        verify: :verify_peer,
        cacertfile: String.to_charlist(CAStore.file_path()),
        depth: 3,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ],
        versions: protocol_versions()
      ]
    ]

    case :httpc.request(:get, {url, []}, http_options, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> body
      other -> raise "couldn't fetch #{url}: #{inspect(other)}"
    end
  end

  defp protocol_versions do
    otp_major_vsn = :erlang.system_info(:otp_release) |> List.to_integer()
    if otp_major_vsn < 25, do: [:"tlsv1.2"], else: [:"tlsv1.2", :"tlsv1.3"]
  end

  def otp_vsn do
    major = to_string(:erlang.system_info(:otp_release))
    path = Path.join([:code.root_dir(), "releases", major, "OTP_VERSION"])

    case File.read(path) do
      {:ok, content} ->
        String.trim(content)

      {:error, _} ->
        IO.warn("unable to read OTP minor version at #{path}. Falling back to #{major}.0")
        "#{major}.0"
    end
  end
end
