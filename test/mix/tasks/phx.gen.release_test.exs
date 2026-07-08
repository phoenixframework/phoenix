Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.Gen.ReleaseTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  @moduletag :capture_log

  setup do
    Mix.Task.clear()

    Process.put({Mix.Tasks.Phx.Gen.Release, :http_client}, fn url ->
      uri = URI.parse(to_string(url))
      params = URI.decode_query(uri.query || "")
      tag = params["tag"] || "1.18.4-erlang-25.3.2.17-debian-trixie-"

      if uri.host == "bob.hex.pm" and uri.path == "/api/docker" do
        bob_tags_response([tag <> "20251117-slim"])
      else
        raise "unexpected URL #{url}"
      end
    end)

    :ok
  end

  test "generates release files", config do
    in_tmp_project(config.test, fn ->
      Gen.Release.run(["--ecto"])

      assert_file("lib/phoenix/release.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Release do|
        assert file =~ ~S|@app :phoenix|
      end)

      assert_file("rel/overlays/bin/migrate", fn file ->
        assert file =~ ~S|exec ./phoenix eval Phoenix.Release.migrate|
      end)

      assert_file("rel/overlays/bin/migrate.bat", fn file ->
        assert file =~ ~S|call "%~dp0\phoenix" eval Phoenix.Release.migrate|
      end)

      assert_file("rel/overlays/bin/server", fn file ->
        assert file =~ ~S|PHX_SERVER=true exec ./phoenix start|
      end)

      assert_file("rel/overlays/bin/server.bat", fn file ->
        assert file =~ "set PHX_SERVER=true\ncall \"%~dp0\\phoenix\" start"
      end)

      refute_file("Dockerfile")
      refute_file(".dockerignore")

      refute_receive {:mix_shell, :info, ["* creating Dockerfile"]}
      refute_receive {:mix_shell, :info, ["* creating .dockerignore"]}
      assert_receive {:mix_shell, :info, ["* creating lib/phoenix/release.ex"]}
      assert_receive {:mix_shell, :info, ["* creating rel/overlays/bin/migrate"]}
      assert_receive {:mix_shell, :info, ["* creating rel/overlays/bin/migrate.bat"]}
      assert_receive {:mix_shell, :info, ["* creating rel/overlays/bin/server"]}
      assert_receive {:mix_shell, :info, ["* creating rel/overlays/bin/server.bat"]}
      assert_receive {:mix_shell, :info, ["\nYour application is ready to be deployed" <> _]}
    end)
  end

  test "generates release files without ecto", config do
    in_tmp_project(config.test, fn ->
      Gen.Release.run([])

      assert_file("rel/overlays/bin/server", fn file ->
        assert file =~ ~S|PHX_SERVER=true exec ./phoenix start|
      end)

      refute_file("lib/phoenix/release.ex")
      refute_file("rel/overlays/bin/migrate")
      refute_file("rel/overlays/bin/migrate.bat")
      refute_file("Dockerfile")
      refute_file(".dockerignore")

      refute_receive {:mix_shell, :info, ["* creating Dockerfile"]}
      refute_receive {:mix_shell, :info, ["* creating .dockerignore"]}
      refute_receive {:mix_shell, :info, ["* creating lib/phoenix/release.ex"]}
      refute_receive {:mix_shell, :info, ["* creating rel/overlays/bin/migrate"]}
      refute_receive {:mix_shell, :info, ["* creating rel/overlays/bin/migrate.bat"]}
      assert_receive {:mix_shell, :info, ["* creating rel/overlays/bin/server"]}
      assert_receive {:mix_shell, :info, ["* creating rel/overlays/bin/server.bat"]}
      assert_receive {:mix_shell, :info, ["\nYour application is ready to be deployed" <> _]}
    end)
  end

  test "generates release and docker files", config do
    in_tmp_project(config.test, fn ->
      Gen.Release.run(["--docker", "--ecto"])

      assert_file("lib/phoenix/release.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Release do|
        assert file =~ ~S|@app :phoenix|
      end)

      assert_file("Dockerfile", fn file ->
        assert file =~
                 ~S|COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/phoenix ./|

        assert file =~ ~S|CMD ["/app/bin/server"]|
      end)

      assert_file("rel/overlays/bin/migrate", fn file ->
        assert file =~ ~S|exec ./phoenix eval Phoenix.Release.migrate|
      end)

      assert_file("rel/overlays/bin/migrate.bat", fn file ->
        assert file =~ ~S|call "%~dp0\phoenix" eval Phoenix.Release.migrate|
      end)

      assert_file("rel/overlays/bin/server", fn file ->
        assert file =~ ~S|PHX_SERVER=true exec ./phoenix start|
      end)

      assert_file("rel/overlays/bin/server.bat", fn file ->
        assert file =~ "set PHX_SERVER=true\ncall \"%~dp0\\phoenix\" start"
      end)

      assert_file(".dockerignore")

      assert_receive {:mix_shell, :info, ["* creating Dockerfile"]}
      assert_receive {:mix_shell, :info, ["* creating .dockerignore"]}
      assert_receive {:mix_shell, :info, ["* creating lib/phoenix/release.ex"]}
      assert_receive {:mix_shell, :info, ["* creating rel/overlays/bin/migrate"]}
      assert_receive {:mix_shell, :info, ["* creating rel/overlays/bin/server"]}
      assert_receive {:mix_shell, :info, ["\nYour application is ready to be deployed" <> _]}
    end)
  end

  test "fetches docker tags from Bob API", config do
    parent = self()

    Process.put({Mix.Tasks.Phx.Gen.Release, :http_client}, fn url ->
      uri = URI.parse(to_string(url))
      send(parent, {:docker_url, uri})

      if uri.host == "bob.hex.pm" and uri.path == "/api/docker" do
        bob_tags_response(["1.18.4-erlang-27.0.3-debian-trixie-20251117-slim"])
      else
        raise "unexpected URL #{url}"
      end
    end)

    in_tmp_project(config.test, fn ->
      Gen.Release.run(["--docker", "--elixir", "1.18.4", "--otp", "27.0.3"])

      assert_file("Dockerfile", fn file ->
        assert file =~ ~S|ARG ELIXIR_VERSION=1.18.4|
        assert file =~ ~S|ARG OTP_VERSION=27.0.3|
        assert file =~ ~S|ARG DEBIAN_VERSION=trixie-20251117-slim|
      end)

      assert_receive {:docker_url, %URI{query: query}}
      assert URI.decode_query(query)["tag"] == "1.18.4-erlang-27.0.3-debian-trixie-"
    end)
  end

  test "falls back to compatible docker image versions", config do
    Process.put({Mix.Tasks.Phx.Gen.Release, :http_client}, fn url ->
      uri = URI.parse(to_string(url))
      params = URI.decode_query(uri.query || "")

      tags =
        case {params["tag"], params["elixir_version"], params["erlang_version"]} do
          {"1.18.3-erlang-27.0.0-debian-trixie-", _, _} ->
            []

          {_, "1.18.3", _} ->
            []

          {_, "1.18", "27.0"} ->
            ["1.18.4-erlang-27.0.3-debian-trixie-20251117-slim"]

          _ ->
            []
        end

      if uri.host == "bob.hex.pm" and uri.path == "/api/docker" do
        bob_tags_response(tags)
      else
        raise "unexpected URL #{url}"
      end
    end)

    in_tmp_project(config.test, fn ->
      Gen.Release.run(["--docker", "--elixir", "1.18.3", "--otp", "27.0.0"])

      assert_file("Dockerfile", fn file ->
        assert file =~ ~S|ARG ELIXIR_VERSION=1.18.4|
        assert file =~ ~S|ARG OTP_VERSION=27.0.3|
      end)
    end)
  end

  test "generates release and docker files with assets dir", config do
    in_tmp_project(config.test, fn ->
      File.mkdir_p!("assets")
      Gen.Release.run(["--docker"])

      assert_file("Dockerfile", fn file ->
        assert file =~ ~S|RUN mix assets.setup|
        assert file =~ ~S|COPY assets assets|
        assert file =~ ~S|RUN mix assets.deploy|
      end)
    end)
  end

  test "generates release and docker files without assets dir", config do
    in_tmp_project(config.test, fn ->
      Gen.Release.run(["--docker"])

      assert_file("Dockerfile", fn file ->
        refute file =~ ~S|RUN mix assets.setup|
        refute file =~ ~S|COPY assets assets|
        refute file =~ ~S|RUN mix assets.deploy|
      end)
    end)
  end

  defp bob_tags_response(tags) do
    Phoenix.json_library().encode!(%{
      tags:
        Enum.map(tags, fn tag ->
          %{
            repo: "hexpm/elixir",
            tag: tag,
            archs: ["amd64", "arm64"],
            built_at: "2025-11-17T00:00:00Z"
          }
        end),
      total: length(tags),
      offset: 0,
      page_size: 100
    })
  end
end
