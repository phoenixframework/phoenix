Code.require_file "mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.New.WebTest do
  use ExUnit.Case
  import MixHelper
  import ExUnit.CaptureIO

  @app_name "phx_web"

  setup do
    # The shell asks to install deps.
    # We will politely say not.
    send self(), {:mix_shell_input, :yes?, false}
    :ok
  end

  test "new without args" do
    in_tmp_umbrella_project "new without args", fn ->
      assert capture_io(fn -> Mix.Tasks.Phx.New.Web.run([]) end) =~
             "Creates a new Phoenix web project within an umbrella application."
    end
  end

  test "new with defaults" do
    in_tmp_umbrella_project "new with defaults", fn ->
      Mix.Tasks.Phx.New.Web.run([@app_name])

      assert_file "phx_web/README.md"
      assert_file "phx_web/mix.exs", fn file ->
        assert file =~ "app: :phx_web"
        assert file =~ "deps_path: \"../../deps\""
        assert file =~ "lockfile: \"../../mix.lock\""
      end

      assert_file "phx_web/config/config.exs", fn file ->
        assert file =~ "ecto_repos: [PhxWeb.Repo]"
        assert file =~ "namespace: PhxWeb"
        refute file =~ "config :phx_web, :generators"
      end

      assert_file "phx_web/config/prod.exs", fn file ->
        assert file =~ "port: 80"
        assert file =~ ":inet6"
      end

      assert_file "phx_web/lib/phx_web/application.ex", ~r/defmodule PhxWeb.Application do/
      assert_file "phx_web/mix.exs", ~r/mod: {PhxWeb.Application, \[\]}/
      assert_file "phx_web/lib/phx_web.ex", fn file ->
        assert file =~ "defmodule PhxWeb do"
        assert file =~ "use Phoenix.View, root: \"lib/phx_web/templates\""
      end
      assert_file "phx_web/lib/phx_web/endpoint.ex", ~r/defmodule PhxWeb.Endpoint do/

      assert_file "phx_web/test/controllers/page_controller_test.exs"
      assert_file "phx_web/test/views/page_view_test.exs"
      assert_file "phx_web/test/views/error_view_test.exs"
      assert_file "phx_web/test/views/layout_view_test.exs"
      assert_file "phx_web/test/support/conn_case.ex"
      assert_file "phx_web/test/test_helper.exs"

      assert_file "phx_web/lib/phx_web/controllers/page_controller.ex",
                  ~r/defmodule PhxWeb.PageController/

      assert_file "phx_web/lib/phx_web/views/page_view.ex",
                  ~r/defmodule PhxWeb.PageView/

      assert_file "phx_web/lib/phx_web/router.ex", "defmodule PhxWeb.Router"
      assert_file "phx_web/lib/phx_web.ex", "defmodule PhxWeb"
      assert_file "phx_web/lib/phx_web/templates/layout/app.html.eex",
                  "<title>Hello PhxWeb!</title>"

      # Brunch
      assert_file "phx_web/.gitignore", "/node_modules"
      assert_file "phx_web/assets/brunch-config.js", ~s("js/app.js": ["js/app"])
      assert_file "phx_web/config/dev.exs", fn file ->
        assert file =~ "watchers: [node:"
        assert file =~ "lib/phx_web/views/.*(ex)"
        assert file =~ "lib/phx_web/templates/.*(eex)"
      end
      assert_file "phx_web/assets/static/favicon.ico"
      assert_file "phx_web/assets/static/images/phoenix.png"
      assert_file "phx_web/assets/css/app.css"
      assert_file "phx_web/assets/js/app.js",
                  ~s[import socket from "./socket"]
      assert_file "phx_web/assets/js/socket.js",
                  ~s[import {Socket} from "phoenix"]

      assert_file "phx_web/assets/package.json", fn file ->
        assert file =~ ~s["file:../../../deps/phoenix"]
        assert file =~ ~s["file:../../../deps/phoenix_html"]
      end

      refute File.exists? "phx_web/priv/static/css/app.css"
      refute File.exists? "phx_web/priv/static/js/phoenix.js"
      refute File.exists? "phx_web/priv/static/js/app.js"

      assert File.exists?("phx_web/assets/vendor")

      # Ecto
      assert_file "phx_web/mix.exs", fn file ->
        assert file =~ "{:phoenix_ecto,"
        assert file =~ "aliases: aliases()"
        refute file =~ "ecto.setup"
        refute file =~ "ecto.reset"
      end
      refute_file "phx_web/lib/phx_web/repo.ex"
      refute_file "phx_web/priv/repo/seeds.exs"
      refute_file "phx_web/test/support/data_case.ex"
      assert_file "phx_web/lib/phx_web.ex", ~r"defmodule PhxWeb"

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are all set!" <> _ = msg]}
      assert msg =~ "$ cd phx_web"
      assert msg =~ "$ mix phx.server"

      refute_received {:mix_shell, :info, ["Before moving on" <> _]}

      # Channels
      assert File.exists?("phx_web/lib/phx_web/channels")
      assert_file "phx_web/lib/phx_web/channels/user_socket.ex", ~r"defmodule PhxWeb.UserSocket"
      assert_file "phx_web/lib/phx_web/endpoint.ex", ~r"socket \"/socket\", PhxWeb.UserSocket"
      assert File.exists?("phx_web/test/channels")

      # Gettext
      assert_file "phx_web/lib/phx_web/gettext.ex", ~r"defmodule PhxWeb.Gettext"
      assert File.exists?("phx_web/priv/gettext/errors.pot")
      assert File.exists?("phx_web/priv/gettext/en/LC_MESSAGES/errors.po")
    end
  end

  test "new without defaults" do
    in_tmp_umbrella_project "new without defaults", fn ->
      Mix.Tasks.Phx.New.Web.run([@app_name, "--no-html", "--no-brunch", "--no-ecto"])

      # No Brunch
      refute File.read!("phx_web/.gitignore") |> String.contains?("/node_modules")
      assert_file "phx_web/config/dev.exs", ~r/watchers: \[\]/

      # No Brunch & No Html
      refute_file "phx_web/priv/static/css/app.css"
      refute_file "phx_web/priv/static/favicon.ico"
      refute_file "phx_web/priv/static/images/phoenix.png"
      refute_file "phx_web/priv/static/js/phoenix.js"
      refute_file "phx_web/priv/static/js/app.js"

      # No Ecto
      config = ~r/config :phx_web, PhxWeb.Repo,/
      refute File.exists?("phx_web/lib/phx_web/repo.ex")

      assert_file "phx_web/mix.exs", &refute(&1 =~ ~r":phoenix_ecto")

      assert_file "phx_web/config/config.exs", fn file ->
        refute file =~ "config :phx_web, :generators"
        refute file =~ "ecto_repos:"
      end

      assert_file "phx_web/config/dev.exs", &refute(&1 =~ config)
      assert_file "phx_web/config/test.exs", &refute(&1 =~ config)
      assert_file "phx_web/config/prod.secret.exs", &refute(&1 =~ config)
      assert_file "phx_web/lib/phx_web.ex", &refute(&1 =~ ~r"alias PhxWeb.Repo")

      # No HTML
      assert File.exists?("phx_web/test/controllers")

      assert File.exists?("phx_web/lib/phx_web/controllers")
      assert File.exists?("phx_web/lib/phx_web/views")

      refute File.exists? "phx_web/test/controllers/pager_controller_test.exs"
      refute File.exists? "phx_web/test/views/layout_view_test.exs"
      refute File.exists? "phx_web/test/views/page_view_test.exs"
      refute File.exists? "phx_web/lib/phx_web/controllers/page_controller.ex"
      refute File.exists? "phx_web/lib/phx_web/templates/layout/app.html.eex"
      refute File.exists? "phx_web/lib/phx_web/templates/page/index.html.eex"
      refute File.exists? "phx_web/lib/phx_web/views/layout_view.ex"
      refute File.exists? "phx_web/lib/phx_web/views/page_view.ex"

      assert_file "phx_web/mix.exs", &refute(&1 =~ ~r":phoenix_html")
      assert_file "phx_web/mix.exs", &refute(&1 =~ ~r":phoenix_live_reload")
      assert_file "phx_web/lib/phx_web/endpoint.ex",
                  &refute(&1 =~ ~r"Phoenix.LiveReloader")
      assert_file "phx_web/lib/phx_web/endpoint.ex",
                  &refute(&1 =~ ~r"Phoenix.LiveReloader.Socket")
      assert_file "phx_web/lib/phx_web/views/error_view.ex", ~r".json"
      assert_file "phx_web/lib/phx_web/router.ex", &refute(&1 =~ ~r"pipeline :browser")
    end
  end

  test "new with no_brunch" do
    in_tmp_umbrella_project "new with no_brunch", fn ->
      Mix.Tasks.Phx.New.Web.run([@app_name, "--no-brunch"])

      assert_file "phx_web/.gitignore"
      assert_file "phx_web/priv/static/css/app.css"
      assert_file "phx_web/priv/static/favicon.ico"
      assert_file "phx_web/priv/static/images/phoenix.png"
      assert_file "phx_web/priv/static/js/phoenix.js"
      assert_file "phx_web/priv/static/js/app.js"
    end
  end

  test "new inside umbrella" do
    in_tmp_umbrella_project "new inside umbrella", fn ->
      File.write! "mix.exs", MixHelper.umbrella_mixfile_contents()
      File.mkdir! "apps"
      File.cd! "apps", fn ->
        Mix.Tasks.Phx.New.Web.run([@app_name])

        assert_file "phx_web/mix.exs", fn file ->
          assert file =~ "deps_path: \"../../deps\""
          assert file =~ "lockfile: \"../../mix.lock\""
        end

        assert_file "phx_web/assets/package.json", fn file ->
          assert file =~ ~s["file:../../../deps/phoenix"]
          assert file =~ ~s["file:../../../deps/phoenix_html"]
        end
      end
    end
  end

  test "new outside umbrella", config do
    in_tmp config.test, fn ->
      assert_raise Mix.Error, ~r"The web task can only be run within an umbrella's apps directory", fn ->
        Mix.Tasks.Phx.New.Web.run ["007invalid"]
      end
    end
  end
end
