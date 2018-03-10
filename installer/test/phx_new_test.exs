Code.require_file "mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.NewTest do
  use ExUnit.Case, async: false
  import MixHelper
  import ExUnit.CaptureIO

  @app_name "phx_blog"

  setup do
    # The shell asks to install deps.
    # We will politely say not.
    send self(), {:mix_shell_input, :yes?, false}
    :ok
  end

  test "returns the version" do
    Mix.Tasks.Phx.New.run(["-v"])
    assert_received {:mix_shell, :info, ["Phoenix v" <> _]}
  end

  test "new with defaults" do
    in_tmp "new with defaults", fn ->
      Mix.Tasks.Phx.New.run([@app_name])

      assert_file "phx_blog/README.md"
      assert_file "phx_blog/mix.exs", fn file ->
        assert file =~ "app: :phx_blog"
        refute file =~ "deps_path: \"../../deps\""
        refute file =~ "lockfile: \"../../mix.lock\""
      end

      assert_file "phx_blog/config/config.exs", fn file ->
        assert file =~ "ecto_repos: [PhxBlog.Repo]"
        assert file =~ "config :phoenix, :json_library, Jason"
        assert file =~ "config :ecto, :json_library, Jason"
        refute file =~ "namespace: PhxBlog"
        refute file =~ "config :phx_blog, :generators"
      end

      assert_file "phx_blog/config/prod.exs", fn file ->
        assert file =~ "port: 80"
        assert file =~ ":inet6"
      end

      assert_file "phx_blog/lib/phx_blog/application.ex", ~r/defmodule PhxBlog.Application do/
      assert_file "phx_blog/lib/phx_blog.ex", ~r/defmodule PhxBlog do/
      assert_file "phx_blog/mix.exs", fn file ->
        assert file =~ "mod: {PhxBlog.Application, []}"
        assert file =~ "{:jason, \"~> 1.0\"}"
      end
      assert_file "phx_blog/lib/phx_blog_web.ex", fn file ->
        assert file =~ "defmodule PhxBlogWeb do"
        assert file =~ "use Phoenix.View, root: \"lib/phx_blog_web/templates\""
      end
      assert_file "phx_blog/lib/phx_blog_web/endpoint.ex", ~r/defmodule PhxBlogWeb.Endpoint do/

      assert_file "phx_blog/test/phx_blog_web/controllers/page_controller_test.exs"
      assert_file "phx_blog/test/phx_blog_web/views/page_view_test.exs"
      assert_file "phx_blog/test/phx_blog_web/views/error_view_test.exs"
      assert_file "phx_blog/test/phx_blog_web/views/layout_view_test.exs"
      assert_file "phx_blog/test/support/conn_case.ex"
      assert_file "phx_blog/test/test_helper.exs"

      assert_file "phx_blog/lib/phx_blog_web/controllers/page_controller.ex",
                  ~r/defmodule PhxBlogWeb.PageController/

      assert_file "phx_blog/lib/phx_blog_web/views/page_view.ex",
                  ~r/defmodule PhxBlogWeb.PageView/

      assert_file "phx_blog/lib/phx_blog_web/router.ex", "defmodule PhxBlogWeb.Router"
      assert_file "phx_blog/lib/phx_blog_web.ex", "defmodule PhxBlogWeb"
      assert_file "phx_blog/lib/phx_blog_web/templates/layout/app.html.eex",
                  "<title>PhxBlog · Phoenix Framework</title>"

      # webpack
      assert_file "phx_blog/.gitignore", "/assets/node_modules/"
      assert_file "phx_blog/.gitignore", "phx_blog-*.tar"
      assert_file "phx_blog/.gitignore", ~r/\n$/
      assert_file "phx_blog/assets/webpack.config.js", "js/app.js"
      assert_file "phx_blog/assets/.babelrc", "env"
      assert_file "phx_blog/config/dev.exs", fn file ->
        assert file =~ "watchers: [node:"
        assert file =~ "lib/phx_blog_web/views/.*(ex)"
        assert file =~ "lib/phx_blog_web/templates/.*(eex)"
      end
      assert_file "phx_blog/assets/static/favicon.ico"
      assert_file "phx_blog/assets/static/images/phoenix.png"
      assert_file "phx_blog/assets/css/app.css"
      assert_file "phx_blog/assets/js/app.js",
                  ~s[import socket from "./socket"]
      assert_file "phx_blog/assets/js/socket.js",
                  ~s[import {Socket} from "phoenix"]

      assert_file "phx_blog/assets/package.json", fn file ->
        assert file =~ ~s["file:../deps/phoenix"]
        assert file =~ ~s["file:../deps/phoenix_html"]
      end

      refute File.exists? "phx_blog/priv/static/css/app.css"
      refute File.exists? "phx_blog/priv/static/js/phoenix.js"
      refute File.exists? "phx_blog/priv/static/js/app.js"

      assert File.exists?("phx_blog/assets/vendor")

      # Ecto
      config = ~r/config :phx_blog, PhxBlog.Repo,/
      assert_file "phx_blog/mix.exs", fn file ->
        assert file =~ "{:phoenix_ecto,"
        assert file =~ "aliases: aliases()"
        assert file =~ "ecto.setup"
        assert file =~ "ecto.reset"
      end
      assert_file "phx_blog/config/dev.exs", config
      assert_file "phx_blog/config/test.exs", config
      assert_file "phx_blog/config/prod.secret.exs", config
      assert_file "phx_blog/lib/phx_blog/repo.ex", ~r"defmodule PhxBlog.Repo"
      assert_file "phx_blog/priv/repo/seeds.exs", ~r"PhxBlog.Repo.insert!"
      assert_file "phx_blog/test/support/data_case.ex", ~r"defmodule PhxBlog.DataCase"
      assert_file "phx_blog/lib/phx_blog_web.ex", ~r"defmodule PhxBlogWeb"

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
      assert msg =~ "$ cd phx_blog"
      assert msg =~ "$ mix deps.get"

      assert_received {:mix_shell, :info, ["Then configure your database in config/dev.exs" <> _]}
      assert_received {:mix_shell, :info, ["Start your Phoenix app" <> _]}

      # Channels
      assert File.exists?("phx_blog/lib/phx_blog_web/channels")
      assert_file "phx_blog/lib/phx_blog_web/channels/user_socket.ex", ~r"defmodule PhxBlogWeb.UserSocket"
      assert_file "phx_blog/lib/phx_blog_web/endpoint.ex", ~r"socket \"/socket\", PhxBlogWeb.UserSocket"
      assert File.exists?("phx_blog/test/phx_blog_web/channels")

      # Gettext
      assert_file "phx_blog/lib/phx_blog_web/gettext.ex", ~r"defmodule PhxBlogWeb.Gettext"
      assert File.exists?("phx_blog/priv/gettext/errors.pot")
      assert File.exists?("phx_blog/priv/gettext/en/LC_MESSAGES/errors.po")
    end
  end

  test "new without defaults" do
    in_tmp "new without defaults", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--no-html", "--no-webpack", "--no-ecto"])

      # No webpack
      refute File.read!("phx_blog/.gitignore") |> String.contains?("/assets/node_modules/")
      assert_file "phx_blog/.gitignore", ~r/\n$/
      assert_file "phx_blog/config/dev.exs", ~r/watchers: \[\]/

      # No webpack & No HTML
      refute_file "phx_blog/priv/static/css/app.css"
      refute_file "phx_blog/priv/static/favicon.ico"
      refute_file "phx_blog/priv/static/images/phoenix.png"
      refute_file "phx_blog/priv/static/js/phoenix.js"
      refute_file "phx_blog/priv/static/js/app.js"

      # No Ecto
      config = ~r/config :phx_blog, PhxBlog.Repo,/
      refute File.exists?("phx_blog/lib/phx_blog/repo.ex")

      assert_file "phx_blog/mix.exs", &refute(&1 =~ ~r":phoenix_ecto")

      assert_file "phx_blog/config/config.exs", fn file ->
        refute file =~ "config :phx_blog, :generators"
        refute file =~ "ecto_repos:"
        refute file =~ "config :ecto, :json_library, Jason"
      end

      assert_file "phx_blog/config/dev.exs", fn file ->
        refute file =~ config
        assert file =~ "config :phoenix, :plug_init_mode, :runtime"
      end
      assert_file "phx_blog/config/test.exs", &refute(&1 =~ config)
      assert_file "phx_blog/config/prod.secret.exs", &refute(&1 =~ config)
      assert_file "phx_blog/lib/phx_blog_web.ex", &refute(&1 =~ ~r"alias PhxBlog.Repo")

      # No HTML
      assert File.exists?("phx_blog/test/phx_blog_web/controllers")

      assert File.exists?("phx_blog/lib/phx_blog_web/controllers")
      assert File.exists?("phx_blog/lib/phx_blog_web/views")

      refute File.exists? "phx_blog/test/web/controllers/pager_controller_test.exs"
      refute File.exists? "phx_blog/test/views/layout_view_test.exs"
      refute File.exists? "phx_blog/test/views/page_view_test.exs"
      refute File.exists? "phx_blog/lib/phx_blog_web/controllers/page_controller.ex"
      refute File.exists? "phx_blog/lib/phx_blog_web/templates/layout/app.html.eex"
      refute File.exists? "phx_blog/lib/phx_blog_web/templates/page/index.html.eex"
      refute File.exists? "phx_blog/lib/phx_blog_web/views/layout_view.ex"
      refute File.exists? "phx_blog/lib/phx_blog_web/views/page_view.ex"

      assert_file "phx_blog/mix.exs", &refute(&1 =~ ~r":phoenix_html")
      assert_file "phx_blog/mix.exs", &refute(&1 =~ ~r":phoenix_live_reload")
      assert_file "phx_blog/lib/phx_blog_web/endpoint.ex",
                  &refute(&1 =~ ~r"Phoenix.LiveReloader")
      assert_file "phx_blog/lib/phx_blog_web/endpoint.ex",
                  &refute(&1 =~ ~r"Phoenix.LiveReloader.Socket")
      assert_file "phx_blog/lib/phx_blog_web/views/error_view.ex", ~r".json"
      assert_file "phx_blog/lib/phx_blog_web/router.ex", &refute(&1 =~ ~r"pipeline :browser")
    end
  end

  test "new with no_webpack" do
    in_tmp "new with no_webpack", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--no-webpack"])

      assert_file "phx_blog/.gitignore"
      assert_file "phx_blog/.gitignore", ~r/\n$/
      assert_file "phx_blog/priv/static/css/app.css"
      assert_file "phx_blog/priv/static/favicon.ico"
      assert_file "phx_blog/priv/static/images/phoenix.png"
      assert_file "phx_blog/priv/static/js/phoenix.js"
      assert_file "phx_blog/priv/static/js/app.js"
    end
  end

  test "new with binary_id" do
    in_tmp "new with binary_id", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--binary-id"])
      assert_file "phx_blog/config/config.exs", ~r/generators: \[binary_id: true\]/
    end
  end

  test "new with uppercase" do
    in_tmp "new with uppercase", fn ->
      Mix.Tasks.Phx.New.run(["phxBlog"])

      assert_file "phxBlog/README.md"

      assert_file "phxBlog/mix.exs", fn file ->
        assert file =~ "app: :phxBlog"
      end

      assert_file "phxBlog/config/dev.exs", fn file ->
        assert file =~ ~r/config :phxBlog, PhxBlog.Repo,/
        assert file =~ "database: \"phxblog_dev\""
      end
    end
  end

  test "new with path, app and module" do
    in_tmp "new with path, app and module", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--app", @app_name, "--module", "PhoteuxBlog"])

      assert_file "custom_path/.gitignore"
      assert_file "custom_path/.gitignore", ~r/\n$/
      assert_file "custom_path/mix.exs", ~r/app: :phx_blog/
      assert_file "custom_path/lib/phx_blog_web/endpoint.ex", ~r/app: :phx_blog/
      assert_file "custom_path/config/config.exs", ~r/namespace: PhoteuxBlog/
      assert_file "custom_path/lib/phx_blog_web.ex", ~r/use Phoenix.Controller, namespace: PhoteuxBlogWeb/
    end
  end

  test "new inside umbrella" do
    in_tmp "new inside umbrella", fn ->
      File.write! "mix.exs", MixHelper.umbrella_mixfile_contents()
      File.mkdir! "apps"
      File.cd! "apps", fn ->
        Mix.Tasks.Phx.New.run([@app_name])

        assert_file "phx_blog/mix.exs", fn file ->
          assert file =~ "deps_path: \"../../deps\""
          assert file =~ "lockfile: \"../../mix.lock\""
        end

        assert_file "phx_blog/assets/package.json", fn file ->
          assert file =~ ~s["file:../../../deps/phoenix"]
          assert file =~ ~s["file:../../../deps/phoenix_html"]
        end
      end
    end
  end

  test "new with mysql adapter" do
    in_tmp "new with mysql adapter", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--database", "mysql"])

      assert_file "custom_path/mix.exs", ~r/:mariaex/
      assert_file "custom_path/config/dev.exs", [~r/Ecto.Adapters.MySQL/, ~r/username: "root"/, ~r/password: ""/]
      assert_file "custom_path/config/test.exs", [~r/Ecto.Adapters.MySQL/, ~r/username: "root"/, ~r/password: ""/]
      assert_file "custom_path/config/prod.secret.exs", [~r/Ecto.Adapters.MySQL/, ~r/username: "root"/, ~r/password: ""/]

      assert_file "custom_path/test/support/conn_case.ex", "Ecto.Adapters.SQL.Sandbox.mode"
      assert_file "custom_path/test/support/channel_case.ex", "Ecto.Adapters.SQL.Sandbox.mode"
      assert_file "custom_path/test/support/data_case.ex", "Ecto.Adapters.SQL.Sandbox.mode"
    end
  end

  test "new defaults to pg adapter" do
    in_tmp "new defaults to pg adapter", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      Mix.Tasks.Phx.New.run([project_path])

      assert_file "custom_path/mix.exs", ~r/:postgrex/
      assert_file "custom_path/config/dev.exs", [~r/Ecto.Adapters.Postgres/, ~r/username: "postgres"/, ~r/password: "postgres"/, ~r/hostname: "localhost"/]
      assert_file "custom_path/config/test.exs", [~r/Ecto.Adapters.Postgres/, ~r/username: "postgres"/, ~r/password: "postgres"/, ~r/hostname: "localhost"/]
      assert_file "custom_path/config/prod.secret.exs", [~r/Ecto.Adapters.Postgres/, ~r/username: "postgres"/, ~r/password: "postgres"/]

      assert_file "custom_path/test/support/conn_case.ex", "Ecto.Adapters.SQL.Sandbox.checkout"
      assert_file "custom_path/test/support/channel_case.ex", "Ecto.Adapters.SQL.Sandbox.checkout"
      assert_file "custom_path/test/support/data_case.ex", "Ecto.Adapters.SQL.Sandbox.checkout"
    end
  end

  test "new with invalid database adapter" do
    in_tmp "new with invalid database adapter", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      assert_raise Mix.Error, ~s(Unknown database "invalid"), fn ->
        Mix.Tasks.Phx.New.run([project_path, "--database", "invalid"])
      end
    end
  end

  test "new with invalid args" do
    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phx.New.run ["007invalid"]
    end

    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phx.New.run ["valid", "--app", "007invalid"]
    end

    assert_raise Mix.Error, ~r"Module name must be a valid Elixir alias", fn ->
      Mix.Tasks.Phx.New.run ["valid", "--module", "not.valid"]
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run ["string"]
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run ["valid", "--app", "mix"]
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run ["valid", "--module", "String"]
    end
  end

  test "invalid options" do
    assert_raise Mix.Error, ~r/Invalid option: -d/, fn ->
      Mix.Tasks.Phx.New.run(["valid", "-database", "mysql"])
    end
  end

  test "new without args" do
    in_tmp "new without args", fn ->
      assert capture_io(fn -> Mix.Tasks.Phx.New.run([]) end) =~
             "Creates a new Phoenix project."
    end
  end
end
