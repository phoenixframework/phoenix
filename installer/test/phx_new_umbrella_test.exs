Code.require_file "mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.NewUmbrellaTest do
  use ExUnit.Case, async: true
  import MixHelper

  @app "phx_umb"

  setup do
    # The shell asks to install deps.
    # We will politely say not.
    send self(), {:mix_shell_input, :yes?, false}
    :ok
  end

  defp root_path(app, path) do
    Path.join(["#{app}_umbrella", path])
  end

  defp app_path(app, path) do
    Path.join(["#{app}_umbrella/apps/#{app}", path])
  end

  defp web_path(app, path) do
    Path.join(["#{app}_umbrella/apps/#{app}_web", path])
  end


  test "new with umbrella and defaults" do
    in_tmp "new with umbrella and defaults", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella"])

      assert_file root_path(@app, "README.md")
      assert_file app_path(@app, "README.md")
      assert_file web_path(@app, "README.md")
      assert_file root_path(@app, "mix.exs"), fn file ->
        assert file =~ "apps_path: \"apps\""
      end
      assert_file app_path(@app, "mix.exs"), fn file ->
        assert file =~ "app: :phx_umb"
        assert file =~ ~S{build_path: "../../_build"}
        assert file =~ ~S{config_path: "../../config/config.exs"}
        assert file =~ ~S{deps_path: "../../deps"}
        assert file =~ ~S{lockfile: "../../mix.lock"}
      end

      assert_file root_path(@app, "config/config.exs"), fn file ->
        assert file =~ ~S{import_config "../apps/*/config/config.exs"}
      end
      assert_file app_path(@app, "config/config.exs"), fn file ->
        assert file =~ "ecto_repos: [PhxUmb.Repo]"
        refute file =~ "namespacej"
        refute file =~ "config :phoenix, :generators"
      end
      assert_file web_path(@app, "config/config.exs"), fn file ->
        assert file =~ "ecto_repos: []"
        assert file =~ ":phx_umb_web, PhxUmb.Web.Endpoint"
        refute file =~ "namespace"
      end

      assert_file web_path(@app, "config/prod.exs"), fn file ->
        assert file =~ "port: 80"
        assert file =~ ":inet6"
      end

      assert_file app_path(@app, "lib/phx_umb.ex"), ~r/defmodule PhxUmb do/
      assert_file app_path(@app, "test/test_helper.exs")
      assert_file app_path(@app, "lib/phx_umb.ex"), ~r/defmodule PhxUmb do/

      assert_file web_path(@app, "lib/phx_umb_web.ex"), ~r/defmodule PhxUmb.Web do/
      assert_file web_path(@app, "lib/endpoint.ex"), ~r/defmodule PhxUmb.Web.Endpoint do/
      assert_file web_path(@app, "test/controllers/page_controller_test.exs")
      assert_file web_path(@app, "test/views/page_view_test.exs")
      assert_file web_path(@app, "test/views/error_view_test.exs")
      assert_file web_path(@app, "test/views/layout_view_test.exs")
      assert_file web_path(@app, "test/support/conn_case.ex")
      assert_file web_path(@app, "test/test_helper.exs")

      assert_file web_path(@app, "lib/controllers/page_controller.ex"),
                  ~r/defmodule PhxUmb.Web.PageController/

      assert_file web_path(@app, "lib/views/page_view.ex"),
                  ~r/defmodule PhxUmb.Web.PageView/

      assert_file web_path(@app, "lib/router.ex"), "defmodule PhxUmb.Web.Router"
      assert_file web_path(@app, "lib/templates/layout/app.html.eex"),
                  "<title>Hello PhxUmb!</title>"

      assert_file web_path(@app, "test/views/page_view_test.exs"),
                  "defmodule PhxUmb.Web.PageViewTest"

      # Brunch
      assert_file web_path(@app, ".gitignore"), "/node_modules"
      assert_file web_path(@app, "assets/brunch-config.js"), ~s("js/app.js": ["js/app"])
      assert_file web_path(@app, "config/dev.exs"), "watchers: [node:"
      assert_file web_path(@app, "assets/static/favicon.ico")
      assert_file web_path(@app, "assets/static/images/phoenix.png")
      assert_file web_path(@app, "assets/css/app.css")
      assert_file web_path(@app, "assets/js/app.js"),
                  ~s[import socket from "./socket"]
      assert_file web_path(@app, "assets/js/socket.js"),
                  ~s[import {Socket} from "phoenix"]

      assert_file web_path(@app, "assets/package.json"), fn file ->
        assert file =~ ~s["file:../../../deps/phoenix"]
        assert file =~ ~s["file:../../../deps/phoenix_html"]
      end

      refute File.exists?(web_path(@app, "priv/static/css/app.css"))
      refute File.exists?(web_path(@app, "priv/static/js/phoenix.js"))
      refute File.exists?(web_path(@app, "priv/static/js/app.js"))

      assert File.exists?(web_path(@app, "assets/vendor"))
      refute File.exists?(web_path(@app, "assets/vendor/.keep"))

      # web deps
      assert_file web_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:phx_umb, in_umbrella: true}"
        assert file =~ "{:phoenix,"
        assert file =~ "{:phoenix_pubsub,"
        assert file =~ "{:gettext,"
        assert file =~ "{:cowboy,"
      end

      # app deps
      assert_file web_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:phoenix_ecto,"
      end

      # Ecto
      config = ~r/config :phx_umb, PhxUmb.Repo,/
      assert_file app_path(@app, "mix.exs"), fn file ->
        assert file =~ "aliases: aliases()"
        assert file =~ "ecto.setup"
        assert file =~ "ecto.reset"
      end

      assert_file app_path(@app, "config/dev.exs"), config
      assert_file app_path(@app, "config/test.exs"), config
      assert_file app_path(@app, "config/prod.secret.exs"), config
      assert_file app_path(@app, "lib/repo.ex"), ~r"defmodule PhxUmb.Repo"
      assert_file app_path(@app, "priv/repo/seeds.exs"), ~r"PhxUmb.Repo.insert!"
      assert_file app_path(@app, "test/support/data_case.ex"), ~r"defmodule PhxUmb.DataCase"

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are all set!" <> _ = msg]}
      assert msg =~ "$ cd phx_umb"
      assert msg =~ "$ mix phoenix.server"

      assert_received {:mix_shell, :info, ["Before moving on," <> _ = msg]}
      assert msg =~ "$ mix ecto.create"

      # Channels
      assert File.exists?(web_path(@app, "/lib/channels"))
      refute File.exists?(web_path(@app, "phx_umb_umbrella/apps/phx_umb_web/lib/channels/.keep"))
      assert_file web_path(@app, "lib/channels/user_socket.ex"), ~r"defmodule PhxUmb.Web.UserSocket"
      assert_file web_path(@app, "lib/endpoint.ex"), ~r"socket \"/socket\", PhxUmb.Web.UserSocket"

      # Gettext
      assert_file web_path(@app, "lib/gettext.ex"), ~r"defmodule PhxUmb.Web.Gettext"
      assert File.exists?(web_path(@app, "priv/gettext/errors.pot"))
      assert File.exists?(web_path(@app, "priv/gettext/en/LC_MESSAGES/errors.po"))
    end
  end

  test "new without defaults" do
    in_tmp "new without defaults", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--no-html", "--no-brunch", "--no-ecto"])

      # No Brunch
      refute File.read!(web_path(@app, ".gitignore")) |> String.contains?("/node_modules")
      assert_file web_path(@app, "config/dev.exs"), ~r/watchers: \[\]/

      # No Brunch & No Html
      refute_file web_path(@app, "priv/static/css/app.css")
      refute_file web_path(@app, "priv/static/favicon.ico")
      refute_file web_path(@app, "priv/static/images/phoenix.png")
      refute_file web_path(@app, "priv/static/js/phoenix.js")
      refute_file web_path(@app, "priv/static/js/app.js")

      # No Ecto
      config = ~r/config :phx_umb, PhxUmb.Repo,/
      refute File.exists?(app_path(@app, "lib/repo.ex"))

      assert_file app_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_ecto")

      assert_file app_path(@app, "config/config.exs"), fn file ->
        refute file =~ "config :phoenix, :generators"
        refute file =~ "ecto_repos:"
      end
      assert_file web_path(@app, "config/config.exs"), fn file ->
        refute file =~ "config :phoenix, :generators"
      end

      assert_file web_path(@app, "config/dev.exs"), &refute(&1 =~ config)
      assert_file web_path(@app, "config/test.exs"), &refute(&1 =~ config)
      assert_file web_path(@app, "config/prod.secret.exs"), &refute(&1 =~ config)

      # No HTML
      assert File.exists?(web_path(@app, "test/controllers"))
      refute File.exists?(web_path(@app, "test/controllers/.keep"))
      assert File.exists?(web_path(@app, "lib/controllers"))
      refute File.exists?(web_path(@app, "lib/controllers/.keep"))
      assert File.exists?(web_path(@app, "lib/views"))
      refute File.exists?(web_path(@app, "lib/views/.keep"))
      refute File.exists?(web_path(@app, "test/controllers/pager_controller_test.exs"))
      refute File.exists?(web_path(@app, "test/views/layout_view_test.exs"))
      refute File.exists?(web_path(@app, "test/views/page_view_test.exs"))
      refute File.exists?(web_path(@app, "lib/controllers/page_controller.ex"))
      refute File.exists?(web_path(@app, "lib/templates/layout/app.html.eex"))
      refute File.exists?(web_path(@app, "lib/templates/page/index.html.eex"))
      refute File.exists?(web_path(@app, "lib/views/layout_view.ex"))
      refute File.exists?(web_path(@app, "lib/views/page_view.ex"))

      assert_file web_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_html")
      assert_file web_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_live_reload")
      assert_file web_path(@app, "lib/endpoint.ex"),
                  &refute(&1 =~ ~r"Phoenix.LiveReloader")
      assert_file web_path(@app, "lib/endpoint.ex"),
                  &refute(&1 =~ ~r"Phoenix.LiveReloader.Socket")
      assert_file web_path(@app, "lib/views/error_view.ex"), ~r".json"
      assert_file web_path(@app, "lib/router.ex"), &refute(&1 =~ ~r"pipeline :browser")
    end
  end

  test "new with no_brunch" do
    in_tmp "new with no_brunch", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--no-brunch"])

      assert_file web_path(@app, ".gitignore")
      assert_file web_path(@app, "priv/static/css/app.css")
      assert_file web_path(@app, "priv/static/favicon.ico")
      assert_file web_path(@app, "priv/static/images/phoenix.png")
      assert_file web_path(@app, "priv/static/js/phoenix.js")
      assert_file web_path(@app, "priv/static/js/app.js")
    end
  end

  test "new with binary_id" do
    in_tmp "new with binary_id", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--binary-id"])

      assert_file app_path(@app, "config/config.exs"), ~r/binary_id: true/
    end
  end

  test "new with uppercase" do
    in_tmp "new with uppercase", fn ->
      Mix.Tasks.Phx.New.run(["phxUmb", "--umbrella"])

      assert_file "phxUmb_umbrella/README.md"

      assert_file "phxUmb_umbrella/apps/phxUmb/mix.exs", fn file ->
        assert file =~ "app: :phxUmb"
      end
      assert_file "phxUmb_umbrella/apps/phxUmb_web/mix.exs", fn file ->
        assert file =~ "app: :phxUmb_web"
      end

      assert_file "phxUmb_umbrella/apps/phxUmb/config/dev.exs", fn file ->
        assert file =~ ~r/config :phxUmb, PhxUmb.Repo,/
        assert file =~ "database: \"phxumb_dev\""
      end
    end
  end

  test "new with path, app and module" do
    in_tmp "new with path, app and module", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--app", @app, "--module", "PhoteuxBlog"])

      assert_file "custom_path_umbrella/apps/phx_umb/mix.exs", ~r/app: :phx_umb/
      assert_file "custom_path_umbrella/apps/phx_umb_web/lib/endpoint.ex", ~r/app: :#{@app}_web/
      assert_file "custom_path_umbrella/apps/phx_umb_web/config/config.exs", ~r/namespace: PhoteuxBlog.Web/
      assert_file "custom_path_umbrella/apps/phx_umb_web/lib/phx_umb_web.ex", ~r/use Phoenix.Controller, namespace: PhoteuxBlog.Web/
    end
  end

  test "new inside umbrella" do
    in_tmp "new inside umbrella", fn ->
      File.write! "mix.exs", MixHelper.umbrella_mixfile_contents()
      File.mkdir! "apps"
      File.cd! "apps", fn ->
        assert_raise Mix.Error, "unable to nest umbrella project within apps", fn ->
          Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        end
      end
    end
  end

  test "new with mysql adapter" do
    in_tmp "new with mysql adapter", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "mysql"])

      assert_file "custom_path_umbrella/apps/custom_path/mix.exs", ~r/:mariaex/
      assert_file "custom_path_umbrella/apps/custom_path/config/dev.exs",
        [~r/Ecto.Adapters.MySQL/, ~r/username: "root"/, ~r/password: ""/]
      assert_file "custom_path_umbrella/apps/custom_path/config/test.exs",
        [~r/Ecto.Adapters.MySQL/, ~r/username: "root"/, ~r/password: ""/]
      assert_file "custom_path_umbrella/apps/custom_path/config/prod.secret.exs",
        [~r/Ecto.Adapters.MySQL/, ~r/username: "root"/, ~r/password: ""/]

      assert_file "custom_path_umbrella/apps/custom_path/test/support/data_case.ex",
        "Ecto.Adapters.SQL.Sandbox.mode"
      assert_file "custom_path_umbrella/apps/custom_path_web/test/support/channel_case.ex",
        "Ecto.Adapters.SQL.Sandbox.mode"
      assert_file "custom_path_umbrella/apps/custom_path_web/test/support/conn_case.ex",
        "Ecto.Adapters.SQL.Sandbox.mode"
    end
  end

  test "new with tds adapter" do
    in_tmp "new with tds adapter", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "mssql"])

      assert_file "custom_path_umbrella/apps/custom_path/mix.exs", ~r/:tds_ecto/
      assert_file "custom_path_umbrella/apps/custom_path/config/dev.exs", ~r/Tds.Ecto/
      assert_file "custom_path_umbrella/apps/custom_path/config/test.exs", ~r/Tds.Ecto/
      assert_file "custom_path_umbrella/apps/custom_path/config/prod.secret.exs", ~r/Tds.Ecto/

      assert_file "custom_path_umbrella/apps/custom_path/test/support/data_case.ex",
        "Ecto.Adapters.SQL.Sandbox.mode"
      assert_file "custom_path_umbrella/apps/custom_path_web/test/support/conn_case.ex",
        "Ecto.Adapters.SQL.Sandbox.mode"
      assert_file "custom_path_umbrella/apps/custom_path_web/test/support/channel_case.ex",
        "Ecto.Adapters.SQL.Sandbox.mode"
    end
  end

  test "new with mongodb adapter" do
    in_tmp "new with mongodb adapter", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "mongodb"])

      assert_file "custom_path_umbrella/apps/custom_path/mix.exs", ~r/:mongodb_ecto/

      assert_file "custom_path_umbrella/apps/custom_path/config/dev.exs", ~r/Mongo.Ecto/
      assert_file "custom_path_umbrella/apps/custom_path/config/test.exs",
        [~r/Mongo.Ecto/, ~r/pool_size: 1/]
      assert_file "custom_path_umbrella/apps/custom_path/config/prod.secret.exs", ~r/Mongo.Ecto/

      assert_file "custom_path_umbrella/apps/custom_path/test/test_helper.exs", fn file ->
        refute file =~ ~r/Ecto.Adapters.SQL/
      end

      assert_file "custom_path_umbrella/apps/custom_path/test/support/data_case.ex",
        "Mongo.Ecto.truncate"
      assert_file "custom_path_umbrella/apps/custom_path_web/test/support/conn_case.ex",
        "Mongo.Ecto.truncate"
      assert_file "custom_path_umbrella/apps/custom_path_web/test/support/channel_case.ex",
        "Mongo.Ecto.truncate"

      assert_file "custom_path_umbrella/apps/custom_path/config/config.exs", fn file ->
        assert file =~ ~r/binary_id: true/
        assert file =~ ~r/migration: false/
        assert file =~ ~r/sample_binary_id: "111111111111111111111111"/
      end
    end
  end

  test "new defaults to pg adapter" do
    in_tmp "new defaults to pg adapter", fn ->
      app = "custom_path"
      project_path = Path.join(File.cwd!, app)
      Mix.Tasks.Phx.New.run([project_path, "--umbrella"])

      assert_file app_path(app, "mix.exs"), ~r/:postgrex/
      assert_file app_path(app, "config/dev.exs"), [~r/Ecto.Adapters.Postgres/, ~r/username: "postgres"/, ~r/password: "postgres"/, ~r/hostname: "localhost"/]
      assert_file app_path(app, "config/test.exs"), [~r/Ecto.Adapters.Postgres/, ~r/username: "postgres"/, ~r/password: "postgres"/, ~r/hostname: "localhost"/]
      assert_file app_path(app, "config/prod.secret.exs"), [~r/Ecto.Adapters.Postgres/, ~r/username: "postgres"/, ~r/password: "postgres"/]

      assert_file web_path(app, "test/support/conn_case.ex"), "Ecto.Adapters.SQL.Sandbox.checkout"
      assert_file web_path(app, "test/support/channel_case.ex"), "Ecto.Adapters.SQL.Sandbox.checkout"
    end
  end

  test "new with invalid database adapter" do
    in_tmp "new with invalid database adapter", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      assert_raise Mix.Error, ~s(Unknown database "invalid"), fn ->
        Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "invalid"])
      end
    end
  end

  test "new with invalid args" do
    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phx.New.run ["007invalid", "--umbrella"]
    end

    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phx.New.run ["valid1", "--app", "007invalid", "--umbrella"]
    end

    assert_raise Mix.Error, ~r"Module name must be a valid Elixir alias", fn ->
      Mix.Tasks.Phx.New.run ["valid2", "--module", "not.valid", "--umbrella"]
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run ["string", "--umbrella"]
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run ["valid3", "--app", "mix", "--umbrella"]
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run ["valid4", "--module", "String", "--umbrella"]
    end
  end

  test "invalid options" do
    assert_raise Mix.Error, ~r/Invalid option: -d/, fn ->
      Mix.Tasks.Phx.New.run(["valid5", "-database", "mysql", "--umbrella"])
    end
  end
end
