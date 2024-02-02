Code.require_file("mix_helper.exs", __DIR__)

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
    send(self(), {:mix_shell_input, :yes?, false})
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
    in_tmp("new with umbrella and defaults", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella"])

      assert_file(root_path(@app, "README.md"))
      assert_file(root_path(@app, ".gitignore"))

      assert_file(app_path(@app, "README.md"))
      assert_file(app_path(@app, ".gitignore"), "#{@app}-*.tar")

      assert_file(web_path(@app, "README.md"))

      assert_file(root_path(@app, "mix.exs"), fn file ->
        assert file =~ "apps_path: \"apps\""
      end)

      # Phoenix.LiveView.HTMLFormatter
      assert_file(root_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:phoenix_live_view, \">= 0.0.0\"}"
      end)

      assert_file(app_path(@app, "mix.exs"), fn file ->
        assert file =~ "app: :phx_umb"
        assert file =~ ~S{build_path: "../../_build"}
        assert file =~ ~S{config_path: "../../config/config.exs"}
        assert file =~ ~S{deps_path: "../../deps"}
        assert file =~ ~S{lockfile: "../../mix.lock"}
      end)

      assert_file(root_path(@app, "config/config.exs"), fn file ->
        assert file =~ ~r/config :esbuild/
        assert file =~ "cd: Path.expand(\"../apps/phx_umb_web/assets\", __DIR__)"
        assert file =~ ~S[import_config "#{config_env()}.exs"]
        assert file =~ "config :phoenix, :json_library, Jason"
        assert file =~ "ecto_repos: [PhxUmb.Repo]"
        assert file =~ ":phx_umb_web, PhxUmbWeb.Endpoint"
        assert file =~ "generators: [context_app: :phx_umb]\n"
        refute file =~ "namespace"
      end)

      assert_file(root_path(@app, "config/dev.exs"), fn file ->
        assert file =~ ~r[esbuild: {Esbuild]
        assert file =~ "lib/#{@app}_web/(controllers|live|components)/.*(ex|heex)"
        assert file =~ "config :#{@app}_web, dev_routes: true"
      end)

      assert_file(root_path(@app, "config/prod.exs"), fn file ->
        assert file =~ "port: 80"
      end)

      assert_file(root_path(@app, "config/runtime.exs"), ~r/ip: {0, 0, 0, 0, 0, 0, 0, 0}/)

      assert_file(root_path(@app, ".formatter.exs"), fn file ->
        assert file =~ "plugins: [Phoenix.LiveView.HTMLFormatter]"
        assert file =~ "inputs: [\"mix.exs\", \"config/*.exs\"]"
        assert file =~ "subdirectories: [\"apps/*\"]"
      end)

      assert_file(app_path(@app, ".formatter.exs"), fn file ->
        assert file =~ "import_deps: [:ecto, :ecto_sql]"
        assert file =~ "subdirectories: [\"priv/*/migrations\"]"
        assert file =~ "plugins: [Phoenix.LiveView.HTMLFormatter]"

        assert file =~
                 "inputs: [\"*.{heex,ex,exs}\", \"{config,lib,test}/**/*.{heex,ex,exs}\", \"priv/*/seeds.exs\"]"
      end)

      assert_file(web_path(@app, ".formatter.exs"), fn file ->
        assert file =~ "import_deps: [:phoenix]"
        assert file =~ "plugins: [Phoenix.LiveView.HTMLFormatter]"
        assert file =~ "inputs: [\"*.{heex,ex,exs}\", \"{config,lib,test}/**/*.{heex,ex,exs}\"]"
        refute file =~ "import_deps: [:ecto]"
        refute file =~ "subdirectories:"
      end)

      assert_file(
        app_path(@app, "lib/#{@app}/application.ex"),
        ~r/defmodule PhxUmb.Application do/
      )

      assert_file(app_path(@app, "lib/#{@app}/application.ex"), ~r/PhxUmb.Repo/)
      assert_file(app_path(@app, "lib/#{@app}.ex"), ~r/defmodule PhxUmb do/)

      assert_file(app_path(@app, "mix.exs"), fn file ->
        assert file =~ "mod: {PhxUmb.Application, []}"
        assert file =~ "{:phoenix_pubsub, \"~> 2.1\"}"
      end)

      assert_file(app_path(@app, "test/test_helper.exs"))

      assert_file(
        web_path(@app, "lib/#{@app}_web/application.ex"),
        ~r/defmodule PhxUmbWeb.Application do/
      )

      assert_file(web_path(@app, "mix.exs"), fn file ->
        assert file =~ "mod: {PhxUmbWeb.Application, []}"
        assert file =~ "{:jason"
      end)

      assert_file(web_path(@app, "lib/#{@app}_web.ex"), fn file ->
        assert file =~ "defmodule PhxUmbWeb do"
        assert file =~ "import Phoenix.HTML"
        assert file =~ "Phoenix.LiveView"
      end)

      assert_file(
        web_path(@app, "lib/#{@app}_web/endpoint.ex"),
        ~r/defmodule PhxUmbWeb.Endpoint do/
      )

      assert_file(web_path(@app, "test/#{@app}_web/controllers/page_controller_test.exs"))
      assert_file(web_path(@app, "test/#{@app}_web/controllers/error_html_test.exs"))
      assert_file(web_path(@app, "test/#{@app}_web/controllers/error_json_test.exs"))
      assert_file(web_path(@app, "test/support/conn_case.ex"))
      assert_file(web_path(@app, "test/test_helper.exs"))

      assert_file(
        web_path(@app, "lib/#{@app}_web/controllers/page_controller.ex"),
        ~r/defmodule PhxUmbWeb.PageController/
      )

      assert_file(
        web_path(@app, "lib/#{@app}_web/controllers/page_html.ex"),
        ~r/defmodule PhxUmbWeb.PageHTML/
      )

      assert_file(web_path(@app, "lib/#{@app}_web/router.ex"), fn file ->
        assert file =~ "defmodule PhxUmbWeb.Router"
        assert file =~ "Application.compile_env(:#{@app}_web, :dev_routes)"
      end)

      assert_file(
        web_path(@app, "lib/#{@app}_web/components/core_components.ex"),
        "defmodule PhxUmbWeb.CoreComponents"
      )

      assert_file(
        web_path(@app, "lib/#{@app}_web/components/layouts.ex"),
        "defmodule PhxUmbWeb.Layouts"
      )

      assert_file(web_path(@app, "lib/#{@app}_web/components/layouts/root.html.heex"), fn file ->
        assert file =~ ~s|<meta name="csrf-token" content={get_csrf_token()} />|
      end)

      assert_file(web_path(@app, "lib/#{@app}_web/components/layouts/app.html.heex"))

      # assets
      assert_file(web_path(@app, ".gitignore"), "/priv/static/assets/")
      assert_file(web_path(@app, ".gitignore"), "#{@app}_web-*.tar")
      assert_file(web_path(@app, ".gitignore"), ~r/\n$/)
      assert_file(web_path(@app, "assets/css/app.css"))

      assert_file(web_path(@app, "assets/tailwind.config.js"), fn file ->
        assert file =~ "phx_umb_web.ex"
        assert file =~ "phx_umb_web/**/*.*ex"
      end)

      assert_file(web_path(@app, "priv/static/favicon.ico"))

      refute File.exists?(web_path(@app, "priv/static/assets/app.css"))
      refute File.exists?(web_path(@app, "priv/static/assets/app.js"))
      assert File.exists?(web_path(@app, "assets/vendor"))

      # web deps
      assert_file(web_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:phx_umb, in_umbrella: true}"
        assert file =~ "{:phoenix,"
        assert file =~ "{:phoenix_live_view,"
        assert file =~ "{:gettext,"
        assert file =~ "{:bandit,"
      end)

      # app deps
      assert_file(web_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:phoenix_ecto,"
        assert file =~ "{:jason,"
      end)

      # Ecto
      config = ~r/config :phx_umb, PhxUmb.Repo,/
      assert_file(root_path(@app, "config/dev.exs"), config)
      assert_file(root_path(@app, "config/test.exs"), config)
      assert_file(root_path(@app, "config/runtime.exs"), config)

      assert_file(app_path(@app, "mix.exs"), fn file ->
        assert file =~ "aliases: aliases()"
        assert file =~ "ecto.setup"
        assert file =~ "ecto.reset"
        assert file =~ "{:jason,"
      end)

      assert_file(app_path(@app, "lib/#{@app}/repo.ex"), ~r"defmodule PhxUmb.Repo")
      assert_file(app_path(@app, "priv/repo/seeds.exs"), ~r"PhxUmb.Repo.insert!")
      assert_file(app_path(@app, "test/support/data_case.ex"), ~r"defmodule PhxUmb.DataCase")

      assert_file(
        app_path(@app, "priv/repo/migrations/.formatter.exs"),
        ~r"import_deps: \[:ecto_sql\]"
      )

      # Telemetry
      assert_file(web_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:telemetry_metrics,"
        assert file =~ "{:telemetry_poller,"
      end)

      assert_file(web_path(@app, "lib/#{@app}_web/telemetry.ex"), fn file ->
        assert file =~ "defmodule PhxUmbWeb.Telemetry do"
        assert file =~ "{:telemetry_poller, measurements: periodic_measurements()"
        assert file =~ "defp periodic_measurements do"
        assert file =~ "# {PhxUmbWeb, :count_users, []}"
        assert file =~ "def metrics do"
        assert file =~ "summary(\"phoenix.endpoint.stop.duration\","
        assert file =~ "summary(\"phoenix.router_dispatch.stop.duration\","
        assert file =~ "# Database Metrics"
        assert file =~ "summary(\"phx_umb.repo.query.total_time\","
      end)

      # Live
      assert_file(web_path(@app, "assets/js/app.js"), fn file ->
        assert file =~ ~s[import {LiveSocket} from "phoenix_live_view"]
      end)

      assert_file(root_path(@app, "config/config.exs"), fn file ->
        assert file =~ "live_view:"
        assert file =~ "signing_salt:"
      end)

      assert_file(web_path(@app, "lib/#{@app}_web.ex"), fn file ->
        assert file =~ "def live_view do"
        assert file =~ "def live_component do"
      end)

      assert_file(
        web_path(@app, "lib/phx_umb_web/endpoint.ex"),
        ~s[socket "/live", Phoenix.LiveView.Socket]
      )

      assert_file(web_path(@app, "lib/phx_umb_web/router.ex"), fn file ->
        assert file =~ ~s[plug :fetch_live_flash]
        assert file =~ ~s[plug :put_root_layout, html: {PhxUmbWeb.Layouts, :root}]
        assert file =~ ~s[get "/", PageController]
      end)

      # Mailer
      assert_file(app_path(@app, "mix.exs"), fn file ->
        assert file =~ "{:swoosh, \"~> 1.5\"}"
        assert file =~ "{:finch, \"~> 0.13\"}"
      end)

      assert_file(app_path(@app, "lib/#{@app}/application.ex"), fn file ->
        assert file =~ "{Finch, name: PhxUmb.Finch}"
      end)

      assert_file(app_path(@app, "lib/#{@app}/mailer.ex"), fn file ->
        assert file =~ "defmodule PhxUmb.Mailer do"
        assert file =~ "use Swoosh.Mailer, otp_app: :phx_umb"
      end)

      assert_file(root_path(@app, "config/config.exs"), fn file ->
        assert file =~ "config :phx_umb, PhxUmb.Mailer, adapter: Swoosh.Adapters.Local"
      end)

      assert_file(root_path(@app, "config/test.exs"), fn file ->
        assert file =~ "config :swoosh"
        assert file =~ "config :phx_umb, PhxUmb.Mailer, adapter: Swoosh.Adapters.Test"
      end)

      assert_file(root_path(@app, "config/dev.exs"), fn file ->
        assert file =~ "config :swoosh"
      end)

      assert_file(root_path(@app, "config/prod.exs"), fn file ->
        assert file =~ "config :swoosh, :api_client, PhxUmb.Finch"
      end)

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
      assert msg =~ "$ cd phx_umb"
      assert msg =~ "$ mix deps.get"

      assert_received {:mix_shell, :info, ["Then configure your database in config/dev.exs" <> _]}
      assert_received {:mix_shell, :info, ["Start your Phoenix app" <> _]}

      # Gettext
      assert_file(web_path(@app, "lib/#{@app}_web/gettext.ex"), ~r"defmodule PhxUmbWeb.Gettext")
      assert File.exists?(web_path(@app, "priv/gettext/errors.pot"))
      assert File.exists?(web_path(@app, "priv/gettext/en/LC_MESSAGES/errors.po"))
    end)
  end

  test "new without defaults" do
    in_tmp("new without defaults", fn ->
      Mix.Tasks.Phx.New.run([
        @app,
        "--umbrella",
        "--no-html",
        "--no-assets",
        "--no-ecto",
        "--no-live",
        "--no-mailer"
      ])

      # No assets
      assert_file(web_path(@app, ".gitignore"), fn file ->
        assert file =~ ~r/\n$/
        refute file =~ "/priv/static/assets/"
      end)

      assert_file(root_path(@app, "config/dev.exs"), ~r/watchers: \[\]/)

      # No assets & No HTML
      refute_file(web_path(@app, "priv/static/assets/app.js"))
      refute_file(web_path(@app, "priv/static/assets/app.css"))

      # No Ecto
      config = ~r/config :phx_umb, PhxUmb.Repo,/
      refute File.exists?(app_path(@app, "lib/#{@app}_web/repo.ex"))

      assert_file(app_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_ecto"))

      assert_file(root_path(@app, "config/config.exs"), fn file ->
        refute file =~ "config :esbuild"
        refute file =~ "config :phx_blog_web, :generators"
        refute file =~ "ecto_repos:"
      end)

      assert_file(web_path(@app, "lib/#{@app}_web/telemetry.ex"), fn file ->
        refute file =~ "# Database Metrics"
        refute file =~ "summary(\"phx_umb.repo.query.total_time\","
      end)

      assert_file(root_path(@app, "config/dev.exs"), &refute(&1 =~ config))
      assert_file(root_path(@app, "config/test.exs"), &refute(&1 =~ config))
      assert_file(root_path(@app, "config/runtime.exs"), &refute(&1 =~ config))

      assert_file(app_path(@app, "lib/#{@app}/application.ex"), ~r/Supervisor.start_link\(/)

      # No LiveView (in web_path)
      assert_file(web_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_live_view"))
      assert_file(web_path(@app, "mix.exs"), &refute(&1 =~ ~r":floki"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/templates/page/hero.html.heex"))

      refute_file(web_path(@app, "assets/js/live.js"))

      # No HTML
      assert File.exists?(web_path(@app, "test/#{@app}_web/controllers"))
      refute File.exists?(web_path(@app, "test/#{@app}_web/controllers/error_html_test.exs"))
      assert File.exists?(web_path(@app, "lib/#{@app}_web/controllers"))
      refute File.exists?(web_path(@app, "test/controllers/page_controller_test.exs"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/controllers/page_controller.ex"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/controllers/error_html.ex"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/controllers/page_html.ex"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/controllers/page_html"))
      refute File.exists?(web_path(@app, "lib/#{@app}_web/components"))

      assert_file(web_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_html"))
      assert_file(web_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_live_reload"))

      assert_file(web_path(@app, "lib/#{@app}_web.ex"), fn file ->
        refute file =~ "defp html_helpers do"
        refute file =~ "Phoenix.HTML"
        refute file =~ "Phoenix.LiveView"
      end)

      assert_file(web_path(@app, "lib/#{@app}_web/endpoint.ex"), fn file ->
        refute file =~ ~r"Phoenix.LiveReloader"
        refute file =~ ~r"Phoenix.LiveReloader.Socket"
      end)

      assert_file(web_path(@app, "lib/#{@app}_web/controllers/error_json.ex"), ~r".json")

      assert_file(
        web_path(@app, "lib/#{@app}_web/router.ex"),
        &refute(&1 =~ ~r"pipeline :browser")
      )

      # Without mailer
      assert_file(web_path(@app, "mix.exs"), fn file ->
        refute file =~ "{:swoosh, \"~> 1.5\"}"
        refute file =~ "{:finch, \"~> 0.13\"}"
      end)

      assert_file(app_path(@app, "lib/#{@app}/application.ex"), fn file ->
        refute file =~ "{Finch, name: PhxUmb.Finch}"
      end)

      refute File.exists?(app_path(@app, "lib/#{@app}/mailer.ex"))

      assert_file(root_path(@app, "config/config.exs"), fn file ->
        refute file =~ "config :swoosh"
        refute file =~ "config :phx_umb, PhxUmb.Mailer, adapter: Swoosh.Adapters.Local"
      end)

      assert_file(root_path(@app, "config/test.exs"), fn file ->
        refute file =~ "config :phx_umb, PhxUmb.Mailer, adapter: Swoosh.Adapters.Test"
      end)

      assert_file(root_path(@app, "config/prod.exs"), fn file ->
        refute file =~ "config :swoosh"
      end)
    end)
  end

  test "new with --no-dashboard" do
    in_tmp("new with no_dashboard", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--no-dashboard"])

      assert_file(web_path(@app, "mix.exs"), &refute(&1 =~ ~r":phoenix_live_dashboard"))

      assert_file(web_path(@app, "lib/#{@app}_web/components/layouts/app.html.heex"), fn file ->
        refute file =~ ~s|LiveDashboard|
      end)

      assert_file(web_path(@app, "lib/#{@app}_web/endpoint.ex"), fn file ->
        assert file =~ ~s|defmodule PhxUmbWeb.Endpoint|
        assert file =~ ~s|socket "/live"|
        refute file =~ ~s|plug Phoenix.LiveDashboard.RequestLogger|
      end)
    end)
  end

  test "new with --no-dashboard and --no-live" do
    in_tmp("new with no_dashboard and no_live", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--no-dashboard", "--no-live"])

      assert_file(web_path(@app, "lib/#{@app}_web/endpoint.ex"), fn file ->
        assert file =~ ~s|# socket "/live"|
      end)

      assert_file(web_path(@app, "assets/js/app.js"), fn file ->
        assert file =~ ~s|// import {Socket} from "phoenix"|
        assert file =~ ~s|// import {LiveSocket} from "phoenix_live_view"|
        assert file =~ ~s|// import topbar from "../vendor/topbar"|
        assert file =~ ~s|// liveSocket.connect()|
      end)
    end)
  end

  test "new with --no-html" do
    in_tmp("new with no_html", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--no-html"])

      assert_file(root_path(@app, "mix.exs"), fn file ->
        assert file =~ "defp deps do\n    []"
      end)

      refute_file(web_path(@app, "test/#{@app}_web/controllers/error_html_test.exs"))

      assert_file(web_path(@app, "mix.exs"), fn file ->
        refute file =~ ~s|:phoenix_live_view|
        assert file =~ ~s|:phoenix_live_dashboard|
      end)

      assert_file(web_path(@app, "lib/#{@app}_web/endpoint.ex"), fn file ->
        assert file =~ ~s|defmodule PhxUmbWeb.Endpoint|
        assert file =~ ~s|socket "/live"|
        assert file =~ ~s|plug Phoenix.LiveDashboard.RequestLogger|
      end)

      assert_file(web_path(@app, "lib/#{@app}_web.ex"), fn file ->
        refute file =~ ~s|Phoenix.HTML|
        refute file =~ ~s|Phoenix.LiveView|
      end)

      assert_file(web_path(@app, "lib/#{@app}_web/router.ex"), fn file ->
        refute file =~ ~s|pipeline :browser|
        assert file =~ ~s|pipe_through [:fetch_session, :protect_from_forgery]|
      end)
    end)
  end

  test "new with --no-assets" do
    in_tmp("new with no_assets", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--no-assets"])

      refute File.read!(web_path(@app, ".gitignore")) |> String.contains?("/priv/static/assets/")
      assert_file(web_path(@app, ".gitignore"), ~r/\n$/)
      assert_file(web_path(@app, "priv/static/assets/app.js"))
      assert_file(web_path(@app, "priv/static/assets/app.css"))
      assert_file(web_path(@app, "priv/static/favicon.ico"))
    end)
  end

  test "new with binary_id" do
    in_tmp("new with binary_id", fn ->
      Mix.Tasks.Phx.New.run([@app, "--umbrella", "--binary-id"])

      assert_file(
        root_path(@app, "config/config.exs"),
        ~r/generators: \[context_app: :phx_umb, binary_id: true\]/
      )
    end)
  end

  test "new with uppercase" do
    in_tmp("new with uppercase", fn ->
      Mix.Tasks.Phx.New.run(["phxUmb", "--umbrella"])

      assert_file("phxUmb_umbrella/README.md")

      assert_file("phxUmb_umbrella/apps/phxUmb/mix.exs", fn file ->
        assert file =~ "app: :phxUmb"
      end)

      assert_file("phxUmb_umbrella/apps/phxUmb_web/mix.exs", fn file ->
        assert file =~ "app: :phxUmb_web"
      end)

      assert_file("phxUmb_umbrella/config/dev.exs", fn file ->
        assert file =~ ~r/config :phxUmb, PhxUmb.Repo,/
        assert file =~ "database: \"phxumb_dev\""
      end)
    end)
  end

  test "new with path, app and module" do
    in_tmp("new with path, app and module", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")

      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--app", @app, "--module", "PhoteuxBlog"])

      assert_file("custom_path_umbrella/apps/phx_umb/mix.exs", ~r/app: :phx_umb/)

      assert_file(
        "custom_path_umbrella/apps/phx_umb_web/lib/phx_umb_web/endpoint.ex",
        ~r/app: :#{@app}_web/
      )

      assert_file(
        "custom_path_umbrella/apps/phx_umb/lib/phx_umb/application.ex",
        ~r/defmodule PhoteuxBlog.Application/
      )

      assert_file(
        "custom_path_umbrella/apps/phx_umb/mix.exs",
        ~r/mod: {PhoteuxBlog.Application, \[\]}/
      )

      assert_file(
        "custom_path_umbrella/apps/phx_umb_web/lib/phx_umb_web/application.ex",
        ~r/defmodule PhoteuxBlogWeb.Application/
      )

      assert_file(
        "custom_path_umbrella/apps/phx_umb_web/mix.exs",
        ~r/mod: {PhoteuxBlogWeb.Application, \[\]}/
      )

      assert_file("custom_path_umbrella/config/config.exs", ~r/namespace: PhoteuxBlogWeb/)
      assert_file("custom_path_umbrella/config/config.exs", ~r/namespace: PhoteuxBlog/)
    end)
  end

  test "new inside umbrella" do
    in_tmp("new inside umbrella", fn ->
      File.write!("mix.exs", MixHelper.umbrella_mixfile_contents())
      File.mkdir!("apps")

      File.cd!("apps", fn ->
        assert_raise Mix.Error, "Unable to nest umbrella project within apps", fn ->
          Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        end
      end)
    end)
  end

  test "new defaults to pg adapter" do
    in_tmp("new defaults to pg adapter", fn ->
      app = "custom_path"
      project_path = Path.join(File.cwd!(), app)
      Mix.Tasks.Phx.New.run([project_path, "--umbrella"])

      assert_file(app_path(app, "mix.exs"), ":postgrex")
      assert_file(app_path(app, "lib/custom_path/repo.ex"), "Ecto.Adapters.Postgres")

      assert_file(root_path(app, "config/dev.exs"), [
        ~r/username: "postgres"/,
        ~r/password: "postgres"/,
        ~r/hostname: "localhost"/
      ])

      assert_file(root_path(app, "config/test.exs"), [
        ~r/username: "postgres"/,
        ~r/password: "postgres"/,
        ~r/hostname: "localhost"/
      ])

      assert_file(root_path(app, "config/runtime.exs"), [~r/url: database_url/])

      assert_file(web_path(app, "test/support/conn_case.ex"), "DataCase.setup_sandbox(tags)")
    end)
  end

  test "new with mysql adapter" do
    in_tmp("new with mysql adapter", fn ->
      app = "custom_path"
      project_path = Path.join(File.cwd!(), app)
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "mysql"])

      assert_file(app_path(app, "mix.exs"), ":myxql")
      assert_file(app_path(app, "lib/custom_path/repo.ex"), "Ecto.Adapters.MyXQL")

      assert_file(root_path(app, "config/dev.exs"), [~r/username: "root"/, ~r/password: ""/])
      assert_file(root_path(app, "config/test.exs"), [~r/username: "root"/, ~r/password: ""/])
      assert_file(root_path(app, "config/runtime.exs"), [~r/url: database_url/])

      assert_file(web_path(app, "test/support/conn_case.ex"), "DataCase.setup_sandbox(tags)")
    end)
  end

  test "new with sqlite3 adapter" do
    in_tmp("new with sqlite3 adapter", fn ->
      app = "custom_path"
      project_path = Path.join(File.cwd!(), app)
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "sqlite3"])

      assert_file(app_path(app, "mix.exs"), ":ecto_sqlite3")
      assert_file(app_path(app, "lib/custom_path/repo.ex"), "Ecto.Adapters.SQLite3")

      assert_file(app_path(app, "lib/custom_path/application.ex"), fn file ->
        assert file =~ "{Ecto.Migrator"
        assert file =~ "repos: Application.fetch_env!(:custom_path, :ecto_repos)"
        assert file =~ "skip: skip_migrations?()"

        assert file =~ "defp skip_migrations?() do"
        assert file =~ ~s/System.get_env("RELEASE_NAME") != nil/
      end)

      assert_file(root_path(app, "config/dev.exs"), [~r/database: .*_dev.db/])
      assert_file(root_path(app, "config/test.exs"), [~r/database: .*_test.db/])
      assert_file(root_path(app, "config/runtime.exs"), [~r/database: database_path/])

      assert_file(web_path(app, "test/support/conn_case.ex"), "DataCase.setup_sandbox(tags)")

      assert_file(root_path(app, ".gitignore"), "*.db")
      assert_file(root_path(app, ".gitignore"), "*.db-*")
    end)
  end

  test "new with mssql adapter" do
    in_tmp("new with mssql adapter", fn ->
      app = "custom_path"
      project_path = Path.join(File.cwd!(), app)
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "mssql"])

      assert_file(app_path(app, "mix.exs"), ":tds")
      assert_file(app_path(app, "lib/custom_path/repo.ex"), "Ecto.Adapters.Tds")

      assert_file(root_path(app, "config/dev.exs"), [
        ~r/username: "sa"/,
        ~r/password: "some!Password"/
      ])

      assert_file(root_path(app, "config/test.exs"), [
        ~r/username: "sa"/,
        ~r/password: "some!Password"/
      ])

      assert_file(root_path(app, "config/runtime.exs"), [~r/url: database_url/])

      assert_file(web_path(app, "test/support/conn_case.ex"), "DataCase.setup_sandbox(tags)")
    end)
  end

  test "new with invalid database adapter" do
    in_tmp("new with invalid database adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")

      assert_raise Mix.Error, ~s(Unknown database "invalid"), fn ->
        Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--database", "invalid"])
      end
    end)
  end

  test "new with cowboy web adapter" do
    in_tmp("new with cowboy web adapter", fn ->
      app = "custom_path"
      project_path = Path.join(File.cwd!(), app)
      Mix.Tasks.Phx.New.run([project_path, "--umbrella", "--adapter", "cowboy"])
      assert_file(web_path(app, "mix.exs"), ":plug_cowboy")

      assert_file(root_path(app, "config/config.exs"), "adapter: Phoenix.Endpoint.Cowboy2Adapter")
    end)
  end

  test "new with invalid args" do
    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phx.New.run(["007invalid", "--umbrella"])
    end

    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phx.New.run(["valid1", "--app", "007invalid", "--umbrella"])
    end

    assert_raise Mix.Error, ~r"Module name must be a valid Elixir alias", fn ->
      Mix.Tasks.Phx.New.run(["valid2", "--module", "not.valid", "--umbrella"])
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run(["string", "--umbrella"])
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run(["valid3", "--app", "mix", "--umbrella"])
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run(["valid4", "--module", "String", "--umbrella"])
    end
  end

  test "invalid options" do
    assert_raise OptionParser.ParseError, fn ->
      Mix.Tasks.Phx.New.run(["valid5", "-database", "mysql", "--umbrella"])
    end
  end

  describe "ecto task" do
    test "can only be run within an umbrella app dir", %{tmp_dir: tmp_dir} do
      in_tmp(tmp_dir, fn ->
        cwd = File.cwd!()
        umbrella_path = root_path(@app)
        Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        flush()

        for dir <- [cwd, umbrella_path] do
          File.cd!(dir, fn ->
            assert_raise Mix.Error,
                         ~r"The ecto task can only be run within an umbrella's apps directory",
                         fn ->
                           Mix.Tasks.Phx.New.Ecto.run(["valid"])
                         end
          end)
        end
      end)
    end
  end

  describe "web task" do
    test "can only be run within an umbrella app dir", %{tmp_dir: tmp_dir} do
      in_tmp(tmp_dir, fn ->
        cwd = File.cwd!()
        umbrella_path = root_path(@app)
        Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        flush()

        for dir <- [cwd, umbrella_path] do
          File.cd!(dir, fn ->
            assert_raise Mix.Error,
                         ~r"The web task can only be run within an umbrella's apps directory",
                         fn ->
                           Mix.Tasks.Phx.New.Web.run(["valid"])
                         end
          end)
        end
      end)
    end

    test "generates web-only files", %{tmp_dir: tmp_dir} do
      in_tmp(tmp_dir, fn ->
        umbrella_path = root_path(@app)
        Mix.Tasks.Phx.New.run([@app, "--umbrella"])
        flush()

        File.cd!(Path.join(umbrella_path, "apps"))
        decline_prompt()
        Mix.Tasks.Phx.New.Web.run(["another"])

        assert_file("another/README.md")

        assert_file("another/mix.exs", fn file ->
          assert file =~ "app: :another"
          assert file =~ "deps_path: \"../../deps\""
          assert file =~ "lockfile: \"../../mix.lock\""
        end)

        assert_file("../config/config.exs", fn file ->
          assert file =~ "ecto_repos: [Another.Repo]"
        end)

        assert_file("../config/prod.exs", fn file ->
          assert file =~ "port: 80"
        end)

        assert_file("../config/runtime.exs", ~r/ip: {0, 0, 0, 0, 0, 0, 0, 0}/)

        assert_file("another/lib/another/application.ex", ~r/defmodule Another.Application do/)
        assert_file("another/mix.exs", ~r/mod: {Another.Application, \[\]}/)
        assert_file("another/lib/another.ex", ~r/defmodule Another do/)
        assert_file("another/lib/another/endpoint.ex", ~r/defmodule Another.Endpoint do/)

        assert_file("another/test/another/controllers/page_controller_test.exs")
        assert_file("another/test/another/controllers/error_html_test.exs")
        assert_file("another/test/another/controllers/error_json_test.exs")
        assert_file("another/test/support/conn_case.ex")
        assert_file("another/test/test_helper.exs")

        assert_file(
          "another/lib/another/controllers/page_controller.ex",
          ~r/defmodule Another.PageController/
        )

        assert File.dir?("another/lib/another/controllers/page_html")

        assert_file(
          "another/lib/another/controllers/page_html.ex",
          ~r/defmodule Another.PageHTML/
        )

        assert_file("another/lib/another/router.ex", "defmodule Another.Router")
        assert_file("another/lib/another.ex", "defmodule Another")
        assert_file("another/lib/another/components/layouts/root.html.heex")
        assert_file("another/lib/another/components/layouts/app.html.heex")

        # assets
        assert_file("another/.gitignore", ~r/\n$/)
        assert_file("another/priv/static/favicon.ico")
        assert_file("another/assets/css/app.css")

        refute File.exists?("another/priv/static/assets/app.css")
        refute File.exists?("another/priv/static/assets/app.js")
        assert File.exists?("another/assets/vendor")

        # Ecto
        assert_file("another/mix.exs", fn file ->
          assert file =~ "{:phoenix_ecto,"
        end)

        assert_file("another/lib/another.ex", ~r"defmodule Another")
        refute_file("another/lib/another/repo.ex")
        refute_file("another/priv/repo/seeds.exs")
        refute_file("another/test/support/data_case.ex")

        # Install dependencies?
        assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

        # Instructions
        assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
        assert msg =~ "$ cd another"
        assert msg =~ "$ mix deps.get"

        refute_received {:mix_shell, :info, ["Then configure your database" <> _]}
        assert_received {:mix_shell, :info, ["Start your Phoenix app" <> _]}

        # Gettext
        assert_file("another/lib/another/gettext.ex", ~r"defmodule Another.Gettext")
        assert File.exists?("another/priv/gettext/errors.pot")
        assert File.exists?("another/priv/gettext/en/LC_MESSAGES/errors.po")
      end)
    end
  end
end
