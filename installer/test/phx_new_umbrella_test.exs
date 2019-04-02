Code.require_file "mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.New.UmbrellaTest do
  use ExUnit.Case, async: false
  import MixHelper

  @app "phx_umb"

  setup config do
    # The shell asks to install deps.
    # We will politely say not.
    decline_prompt()
    {:ok, tmp_dir: to_string(config.test)}
  end

  defp decline_prompt do
    send self(), {:mix_shell_input, :yes?, false}
  end

  defp root_path(app, path \\ "") do
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
      assert_file root_path(@app, ".gitignore")

      assert_file app_path(@app, "README.md")
      assert_file app_path(@app, ".gitignore"), "#{@app}-*.tar"

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
        assert file =~ ~S[import_config "../apps/*/config/config.exs"]
        assert file =~ ~S[import_config "#{Mix.env()}.exs"]
        assert file =~ "config :phoenix, :json_library, Jason"
      end

      assert_file app_path(@app, "config/config.exs"), fn file ->
        assert file =~ "ecto_repos: [PhxUmb.Repo]"
        refute file =~ "namespace"
        refute file =~ "config :phx_blog_web, :generators"
      end

      assert_file web_path(@app, "config/config.exs"), fn file ->
        assert file =~ "ecto_repos: [PhxUmb.Repo]"
        assert file =~ ":phx_umb_web, PhxUmbWeb.Endpoint"
        assert file =~ "generators: [context_app: :phx_umb]\n"
      end

      assert_file web_path(@app, "config/prod.exs"), fn file ->
        assert file =~ "port: 80"
        assert file =~ ":inet6"
      end

      assert_file app_path(@app, ".formatter.exs"), fn file ->
        assert file =~ "import_deps: [:ecto]"
        assert file =~ "inputs: [\"*.{ex,exs}\", \"priv/*/seeds.exs\", \"{config,lib,test}/**/*.{ex,exs}\"]"
        assert file =~ "subdirectories: [\"priv/*/migrations\"]"
      end

      assert_file web_path(@app, ".formatter.exs"), fn file ->
        assert file =~ "inputs: [\"*.{ex,exs}\", \"{config,lib,test}/**/*.{ex,exs}\"]"
        refute file =~ "import_deps: [:ecto]"
        refute file =~ "subdirectories:"
      end

      assert_file app_path(@app, "lib/#{@app}/application.ex"), ~r/defmodule PhxUmb.Application do/
      assert_file app_path(@app, "lib/#{@app}/application.ex"), ~r/PhxUmb.Repo/
      assert_file app_path(@app, "lib/#{@app}.ex"), ~r/defmodule PhxUmb do/
      assert_file app_path(@app, "mix.exs"), ~r/mod: {PhxUmb.Application, \[\]}/
      assert_file app_path(@app, "test/test_helper.exs")

      assert_file web_path(@app, "lib/#{@app}_web/application.ex"), ~r/defmodule PhxUmbWeb.Application do/
      assert_file web_path(@app, "mix.exs"), fn file ->
        assert file =~ "mod: {PhxUmbWeb.Application, []}"
        assert file =~ "{:jason, \"~> 1.0\"}"
      end
      assert_file web_path(@app, "lib/#{@app}_web.ex"), fn file ->
        assert file =~ "defmodule PhxUmbWeb do"
        assert file =~ ~r/use Phoenix.View,\s+root: "lib\/phx_umb_web\/templates"/
      end
      assert_file web_path(@app, "lib/#{@app}_web/endpoint.ex"), ~r/defmodule PhxUmbWeb.Endpoint do/
      assert_file web_path(@app, "test/#{@app}_web/controllers/page_controller_test.exs")
      assert_file web_path(@app, "test/#{@app}_web/views/page_view_test.exs")
      assert_file web_path(@app, "test/#{@app}_web/views/error_view_test.exs")
      assert_file web_path(@app, "test/#{@app}_web/views/layout_view_test.exs")
      assert_file web_path(@app, "test/support/conn_case.ex")
      assert_file web_path(@app, "test/test_helper.exs")

      assert_file web_path(@app, "lib/#{@app}_web/controllers/page_controller.ex"),
                  ~r/defmodule PhxUmbWeb.PageController/

      assert_file web_path(@app, "lib/#{@app}_web/views/page_view.ex"),
                  ~r/defmodule PhxUmbWeb.PageView/

      assert_file web_path(@app, "lib/#{@app}_web/router.ex"), "defmodule PhxUmbWeb.Router"
      assert_file web_path(@app, "lib/#{@app}_web/templates/layout/app.html.eex"),
                  "<title>PhxUmb · Phoenix Framework</title>"

      assert_file web_path(@app, "test/#{@app}_web/views/page_view_test.exs"),
                  "defmodule PhxUmbWeb.PageViewTest"

      # webpack
      assert_file web_path(@app, ".gitignore"), "/assets/node_modules/"
      assert_file web_path(@app, ".gitignore"), "#{@app}_web-*.tar"
      assert_file( web_path(@app, ".gitignore"),  ~r/\n$/)
      assert_file web_path(@app, "assets/webpack.config.js"), "js/app.js"
      assert_file web_path(@app, "assets/.babelrc"), "env"
      assert_file web_path(@app, "config/dev.exs"), fn file ->
        assert file =~ ~r/watchers: \[\s+node:/
        assert file =~ "lib/#{@app}_web/{live,views}/.*(ex)"
        assert file =~ "lib/#{@app}_web/templates/.*(eex)"
      end
      assert_file web_path(@app, "assets/static/favicon.ico")
      assert_file web_path(@app, "assets/static/images/phoenix.png")
      assert_file web_path(@app, "assets/css/app.css")
      assert_file web_path(@app, "assets/css/phoenix.css")
      assert_file web_path(@app, "assets/js/app.js"),
                  ~s[import socket from "./socket"]
      assert_file web_path(@app, "assets/js/socket.js"),
                  ~s[import {Socket} from "phoenix"]

      assert_file web_path(@app, "assets/package.json"), fn file ->
        assert file =~ ~s["file:../../../deps/phoenix"]
        assert file =~ ~s["file:../../../deps/phoenix_html"]
      end

      refute File.exists?(web_path(@app, "priv/static/css/app.css"))
      refute File.exists?(web_path(@app, "priv/static/css/phoenix.css"))
      refute File.exists?(web_path(@app, "priv/static/js/phoenix.js"))
      refute File.exists?(web_path(@app, "priv/static/js/app.js"))

      assert File.exists?(web_path(@app, "assets/vendor"))

      # web deps
      assert_file web_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:phx_umb, in_umbrella: true}"
        assert file =~ "{:phoenix,"
        assert file =~ "{:phoenix_pubsub,"
        assert file =~ "{:gettext,"
        assert file =~ "{:plug_cowboy,"
      end

      # app deps
      assert_file web_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:phoenix_ecto,"
        assert file =~ "{:jason,"
      end

      # Ecto
      config = ~r/config :phx_umb, PhxUmb.Repo,/
      assert_file app_path(@app, "mix.exs"), fn file ->
        assert file =~ "aliases: aliases()"
        assert file =~ "ecto.setup"
        assert file =~ "ecto.reset"
        assert file =~ "{:jason,"
      end

      assert_file app_path(@app, "config/dev.exs"), config
      assert_file app_path(@app, "config/test.exs"), config
      assert_file app_path(@app, "config/prod.secret.exs"), config
      assert_file app_path(@app, "lib/#{@app}/repo.ex"), ~r"defmodule PhxUmb.Repo"
      assert_file app_path(@app, "priv/repo/seeds.exs"), ~r"PhxUmb.Repo.insert!"
      assert_file app_path(@app, "test/support/data_case.ex"), ~r"defmodule PhxUmb.DataCase"
      assert_file app_path(@app, "priv/repo/migrations/.formatter.exs"), ~r"import_deps: \[:ecto_sql\]"

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
      assert msg =~ "$ cd phx_umb"
      assert msg =~ "$ mix deps.get"

      assert_received {:mix_shell, :info, ["Then configure your database in apps/phx_umb/config/dev.exs" <> _]}
      assert_received {:mix_shell, :info, ["Start your Phoenix app" <> _]}

      # Channels
      assert File.exists?(web_path(@app, "/lib/#{@app}_web/channels"))
      assert_file web_path(@app, "lib/#{@app}_web/channels/user_socket.ex"), ~r"defmodule PhxUmbWeb.UserSocket"
      assert_file web_path(@app, "lib/#{@app}_web/endpoint.ex"), ~r"socket \"/socket\", PhxUmbWeb.UserSocket"

      # Gettext
      assert_file web_path(@app, "lib/#{@app}_web/gettext.ex"), ~r"defmodule PhxUmbWeb.Gettext"
      assert File.exists?(web_path(@app, "priv/gettext/errors.pot"))
      assert File.exists?(web_path(@app, "priv/gettext/en/LC_MESSAGES/errors.po"))
    end
  end

  test "new without defaults" do
    in_tmp "new without defaults", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--no-html", "--no-webpack", "--no-ecto"])

      # No webpack
      refute File.read!(web_path(@app, ".gitignore")) |> String.contains?("/assets/node_modules/")
      assert_file( web_path(@app, ".gitignore"),  ~r/\n$/)
      assert_file web_path(@app, "config/dev.exs"), ~r/watchers: \[\]/

      # No webpack & No HTML
      refute_file web_path(@app, "priv/static/css/app.css")
      refute_file web_path(@app, "priv/static/css/phoenix.css")
      refute_file web_path(@app, "priv/static/favicon.ico")
      refute_file web_path(@app, "priv/static/images/phoenix.png")
      refute_file web_path(@app, "priv/static/js/phoenix.js")
      refute_file web_path(@app, "priv/static/js/app.js")

      # No Ecto
      config = ~r/config :phx_umb, PhxUmb.Repo,/
      refute File.exists?(app_path(@app, "lib/#{@app}_web/repo.ex"))

      assert_file app_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_ecto")

      assert_file app_path(@app, "config/config.exs"), fn file ->
        refute file =~ "config :phx_blog_web, :generators"
        refute file =~ "ecto_repos:"
      end
      assert_file web_path(@app, "config/config.exs"), fn file ->
        refute file =~ "config :phx_blog_web, :generators"
      end

      assert_file web_path(@app, "config/dev.exs"), fn file ->
        refute file =~ config
      end
      assert_file web_path(@app, "config/test.exs"), &refute(&1 =~ config)
      assert_file web_path(@app, "config/prod.secret.exs"), &refute(&1 =~ config)

      assert_file app_path(@app, "lib/#{@app}/application.ex"), ~r/Supervisor.start_link\(/

      # No HTML
      assert File.exists?(web_path(@app, "test/#{@app}_web/controllers"))
      assert File.exists?(web_path(@app, "lib/#{@app}_web/controllers"))
      assert File.exists?(web_path(@app, "lib/#{@app}_web/views"))
      refute File.exists?(web_path(@app, "test/controllers/pager_controller_test.exs"))
      refute File.exists?(web_path(@app, "test/views/layout_view_test.exs"))
      refute File.exists?(web_path(@app, "test/views/page_view_test.exs"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/controllers/page_controller.ex"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/templates/layout/app.html.eex"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/templates/page/index.html.eex"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/views/layout_view.ex"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/views/page_view.ex"))

      assert_file web_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_html")
      assert_file web_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_live_reload")
      assert_file web_path(@app, "lib/#{@app}_web/endpoint.ex"),
                  &refute(&1 =~ ~r"Phoenix.LiveReloader")
      assert_file web_path(@app, "lib/#{@app}_web/endpoint.ex"),
                  &refute(&1 =~ ~r"Phoenix.LiveReloader.Socket")
      assert_file web_path(@app, "lib/#{@app}_web/views/error_view.ex"), ~r".json"
      assert_file web_path(@app, "lib/#{@app}_web/router.ex"), &refute(&1 =~ ~r"pipeline :browser")
    end
  end

  test "new with no_webpack" do
    in_tmp "new with no_webpack", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--no-webpack"])

      assert_file web_path(@app, ".gitignore")
      assert_file( web_path(@app, ".gitignore"),  ~r/\n$/)
      assert_file web_path(@app, "priv/static/css/app.css")
      assert_file web_path(@app, "priv/static/css/phoenix.css")
      assert_file web_path(@app, "priv/static/favicon.ico")
      assert_file web_path(@app, "priv/static/images/phoenix.png")
      assert_file web_path(@app, "priv/static/js/phoenix.js")
      assert_file web_path(@app, "priv/static/js/app.js")
    end
  end

  test "new with binary_id" do
    in_tmp "new with binary_id", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--binary-id"])
      assert_file web_path(@app, "config/config.exs"), ~r/generators: \[context_app: :phx_umb, binary_id: true\]/
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
      assert_file "custom_path_umbrella/apps/phx_umb_web/lib/phx_umb_web/endpoint.ex", ~r/app: :#{@app}_web/
      assert_file "custom_path_umbrella/apps/phx_umb_web/config/config.exs", ~r/namespace: PhoteuxBlogWeb/
      assert_file "custom_path_umbrella/apps/phx_umb_web/lib/#{@app}_web.ex", ~r/use Phoenix.Controller, namespace: PhoteuxBlogWeb/
      assert_file "custom_path_umbrella/apps/phx_umb/lib/phx_umb/application.ex", ~r/defmodule PhoteuxBlog.Application/
      assert_file "custom_path_umbrella/apps/phx_umb/mix.exs", ~r/mod: {PhoteuxBlog.Application, \[\]}/
      assert_file "custom_path_umbrella/apps/phx_umb_web/lib/phx_umb_web/application.ex", ~r/defmodule PhoteuxBlogWeb.Application/
      assert_file "custom_path_umbrella/apps/phx_umb_web/mix.exs", ~r/mod: {PhoteuxBlogWeb.Application, \[\]}/
      assert_file "custom_path_umbrella/apps/phx_umb/config/config.exs", ~r/namespace: PhoteuxBlog/
    end
  end

  test "new inside umbrella" do
    in_tmp "new inside umbrella", fn ->
      File.write! "mix.exs", MixHelper.umbrella_mixfile_contents()
      File.mkdir! "apps"
      File.cd! "apps", fn ->
        assert_raise Mix.Error, "Unable to nest umbrella project within apps", fn ->
          Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        end
      end
    end
  end

  test "new defaults to pg adapter" do
    in_tmp "new defaults to pg adapter", fn ->
      app = "custom_path"
      project_path = Path.join(File.cwd!, app)
      Mix.Tasks.Phx.New.run([project_path, "--umbrella"])

      assert_file app_path(app, "mix.exs"), ":postgrex"
      assert_file app_path(app, "config/dev.exs"), [~r/username: "postgres"/, ~r/password: "postgres"/, ~r/hostname: "localhost"/]
      assert_file app_path(app, "config/test.exs"), [~r/username: "postgres"/, ~r/password: "postgres"/, ~r/hostname: "localhost"/]
      assert_file app_path(app, "config/prod.secret.exs"), [~r/username: "postgres"/, ~r/password: "postgres"/]
      assert_file app_path(app, "lib/custom_path/repo.ex"), "Ecto.Adapters.Postgres"

      assert_file web_path(app, "test/support/conn_case.ex"), "Ecto.Adapters.SQL.Sandbox.checkout"
      assert_file web_path(app, "test/support/channel_case.ex"), "Ecto.Adapters.SQL.Sandbox.checkout"
    end
  end

  test "new with mysql adapter" do
    in_tmp "new with mysql adapter", fn ->
      app = "custom_path"
      project_path = Path.join(File.cwd!, app)
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "mysql"])

      assert_file app_path(app, "mix.exs"), ":myxql"
      assert_file app_path(app, "config/dev.exs"), [~r/username: "root"/, ~r/password: ""/]
      assert_file app_path(app, "config/test.exs"), [~r/username: "root"/, ~r/password: ""/]
      assert_file app_path(app, "config/prod.secret.exs"), [~r/username: "root"/, ~r/password: ""/]
      assert_file app_path(app, "lib/custom_path/repo.ex"), "Ecto.Adapters.MyXQL"

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

  describe "ecto task" do
    test "can only be run within an umbrella app dir", %{tmp_dir: tmp_dir} do
      in_tmp tmp_dir, fn ->
        cwd = File.cwd!()
        umbrella_path = root_path(@app)
        Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        flush()

        for dir <- [cwd, umbrella_path] do
          File.cd!(dir, fn ->
            assert_raise Mix.Error, ~r"The ecto task can only be run within an umbrella's apps directory", fn ->
              Mix.Tasks.Phx.New.Ecto.run(["valid"])
            end
          end)
        end
      end
    end
  end

  describe "web task" do
    test "can only be run within an umbrella app dir", %{tmp_dir: tmp_dir} do
      in_tmp tmp_dir, fn ->
        cwd = File.cwd!()
        umbrella_path = root_path(@app)
        Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        flush()

        for dir <- [cwd, umbrella_path] do
          File.cd!(dir, fn ->
            assert_raise Mix.Error, ~r"The web task can only be run within an umbrella's apps directory", fn ->
              Mix.Tasks.Phx.New.Web.run(["valid"])
            end
          end)
        end
      end
    end

    test "generates web-only files", %{tmp_dir: tmp_dir} do
      in_tmp tmp_dir, fn ->
        umbrella_path = root_path(@app)
        Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        flush()

        File.cd!(Path.join(umbrella_path, "apps"))
        decline_prompt()
        Mix.Tasks.Phx.New.Web.run(["another"])

        assert_file "another/README.md"
        assert_file "another/mix.exs", fn file ->
          assert file =~ "app: :another"
          assert file =~ "deps_path: \"../../deps\""
          assert file =~ "lockfile: \"../../mix.lock\""
        end

        assert_file "another/config/config.exs", fn file ->
          assert file =~ "ecto_repos: [Another.Repo]"
        end

        assert_file "another/config/prod.exs", fn file ->
          assert file =~ "port: 80"
          assert file =~ ":inet6"
        end

        assert_file "another/lib/another/application.ex", ~r/defmodule Another.Application do/
        assert_file "another/mix.exs", ~r/mod: {Another.Application, \[\]}/
        assert_file "another/lib/another.ex", ~r/defmodule Another do/
        assert_file "another/lib/another/endpoint.ex", ~r/defmodule Another.Endpoint do/

        assert_file "another/test/another/controllers/page_controller_test.exs"
        assert_file "another/test/another/views/page_view_test.exs"
        assert_file "another/test/another/views/error_view_test.exs"
        assert_file "another/test/another/views/layout_view_test.exs"
        assert_file "another/test/support/conn_case.ex"
        assert_file "another/test/test_helper.exs"

        assert_file "another/lib/another/controllers/page_controller.ex",
                    ~r/defmodule Another.PageController/

        assert_file "another/lib/another/views/page_view.ex",
                    ~r/defmodule Another.PageView/

        assert_file "another/lib/another/router.ex", "defmodule Another.Router"
        assert_file "another/lib/another.ex", "defmodule Another"
        assert_file "another/lib/another/templates/layout/app.html.eex",
                    "<title>Another · Phoenix Framework</title>"

        # webpack
        assert_file "another/.gitignore", "/assets/node_modules"
        assert_file "another/.gitignore",  ~r/\n$/
        assert_file "another/assets/webpack.config.js", "js/app.js"
        assert_file "another/assets/.babelrc", "env"
        assert_file "another/config/dev.exs", ~r/watchers: \[\s+node:/
        assert_file "another/assets/static/favicon.ico"
        assert_file "another/assets/static/images/phoenix.png"
        assert_file "another/assets/css/app.css"
        assert_file "another/assets/css/phoenix.css"
        assert_file "another/assets/js/app.js",
                    ~s[import socket from "./socket"]
        assert_file "another/assets/js/socket.js",
                    ~s[import {Socket} from "phoenix"]

        assert_file "another/assets/package.json", fn file ->
          assert file =~ ~s["file:../../../deps/phoenix"]
          assert file =~ ~s["file:../../../deps/phoenix_html"]
        end

        refute File.exists? "another/priv/static/css/app.css"
        refute File.exists? "another/priv/static/js/phoenix.js"
        refute File.exists? "another/priv/static/css/phoenix.css"
        refute File.exists? "another/priv/static/js/app.js"

        assert File.exists?("another/assets/vendor")

        # Ecto
        assert_file "another/mix.exs", fn file ->
          assert file =~ "{:phoenix_ecto,"
        end
        assert_file "another/lib/another.ex", ~r"defmodule Another"
        refute_file "another/lib/another/repo.ex"
        refute_file "another/priv/repo/seeds.exs"
        refute_file "another/test/support/data_case.ex"

        # Install dependencies?
        assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

        # Instructions
        assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
        assert msg =~ "$ cd another"
        assert msg =~ "$ mix deps.get"

        refute_received {:mix_shell, :info, ["Then configure your database" <> _]}
        assert_received {:mix_shell, :info, ["Start your Phoenix app" <> _]}

        # Channels
        assert File.exists?("another/lib/another/channels")
        assert_file "another/lib/another/channels/user_socket.ex", ~r"defmodule Another.UserSocket"
        assert_file "another/lib/another/endpoint.ex", ~r"socket \"/socket\", Another.UserSocket"

        # Gettext
        assert_file "another/lib/another/gettext.ex", ~r"defmodule Another.Gettext"
        assert File.exists?("another/priv/gettext/errors.pot")
        assert File.exists?("another/priv/gettext/en/LC_MESSAGES/errors.po")
      end
    end
  end
end
