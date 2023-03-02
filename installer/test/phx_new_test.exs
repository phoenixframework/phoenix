Code.require_file("mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.NewTest do
  use ExUnit.Case, async: false
  import MixHelper
  import ExUnit.CaptureIO

  @app_name "phx_blog"

  setup do
    # The shell asks to install deps.
    # We will politely say not.
    send(self(), {:mix_shell_input, :yes?, false})
    :ok
  end

  test "assets are in sync with priv" do
    for file <- ~w(favicon.ico phoenix.png) do
      assert File.read!("../priv/static/#{file}") ==
               File.read!("templates/phx_static/#{file}")
    end
  end

  test "components are in sync with priv" do
    assert File.read!("../priv/templates/phx.gen.live/core_components.ex") ==
             File.read!("templates/phx_web/components/core_components.ex")
  end

  test "returns the version" do
    Mix.Tasks.Phx.New.run(["-v"])
    assert_received {:mix_shell, :info, ["Phoenix installer v" <> _]}
  end

  test "new with defaults" do
    in_tmp("new with defaults", fn ->
      Mix.Tasks.Phx.New.run([@app_name])

      assert_file("phx_blog/README.md")

      assert_file("phx_blog/.formatter.exs", fn file ->
        assert file =~ "import_deps: [:ecto, :ecto_sql, :phoenix]"
        assert file =~ "subdirectories: [\"priv/*/migrations\"]"
        assert file =~ "plugins: [Phoenix.LiveView.HTMLFormatter]"

        assert file =~
                 "inputs: [\"*.{heex,ex,exs}\", \"{config,lib,test}/**/*.{heex,ex,exs}\", \"priv/*/seeds.exs\"]"
      end)

      assert_file("phx_blog/mix.exs", fn file ->
        assert file =~ "app: :phx_blog"
        refute file =~ "deps_path: \"../../deps\""
        refute file =~ "lockfile: \"../../mix.lock\""
      end)

      assert_file("phx_blog/config/config.exs", fn file ->
        assert file =~ "ecto_repos: [PhxBlog.Repo]"
        assert file =~ "config :phoenix, :json_library, Jason"
        refute file =~ "namespace: PhxBlog"
        refute file =~ "config :phx_blog, :generators"
      end)

      assert_file("phx_blog/config/prod.exs", fn file ->
        assert file =~ "config :logger, level: :info"
      end)

      assert_file("phx_blog/config/runtime.exs", ~r/ip: {0, 0, 0, 0, 0, 0, 0, 0}/)

      assert_file("phx_blog/lib/phx_blog/application.ex", ~r/defmodule PhxBlog.Application do/)
      assert_file("phx_blog/lib/phx_blog.ex", ~r/defmodule PhxBlog do/)

      assert_file("phx_blog/mix.exs", fn file ->
        assert file =~ "mod: {PhxBlog.Application, []}"
        assert file =~ "{:jason,"
        assert file =~ "{:phoenix_live_dashboard,"
      end)

      assert_file("phx_blog/lib/phx_blog_web.ex", fn file ->
        assert file =~ "defmodule PhxBlogWeb do"
        assert file =~ "import Phoenix.HTML"
        assert file =~ "Phoenix.LiveView"
      end)

      assert_file("phx_blog/test/phx_blog_web/controllers/page_controller_test.exs")
      assert_file("phx_blog/test/phx_blog_web/controllers/error_html_test.exs")
      assert_file("phx_blog/test/phx_blog_web/controllers/error_json_test.exs")
      assert_file("phx_blog/test/support/conn_case.ex")
      assert_file("phx_blog/test/test_helper.exs")

      assert_file(
        "phx_blog/lib/phx_blog_web/controllers/page_controller.ex",
        ~r/defmodule PhxBlogWeb.PageController/
      )

      assert_file(
        "phx_blog/lib/phx_blog_web/controllers/page_html.ex",
        ~r/defmodule PhxBlogWeb.PageHTML/
      )

      assert_file(
        "phx_blog/lib/phx_blog_web/controllers/error_html.ex",
        ~r/defmodule PhxBlogWeb.ErrorHTML/
      )

      assert_file(
        "phx_blog/lib/phx_blog_web/controllers/error_json.ex",
        ~r/defmodule PhxBlogWeb.ErrorJSON/
      )

      assert_file("phx_blog/lib/phx_blog_web/components/core_components.ex", fn file ->
        assert file =~ "defmodule PhxBlogWeb.CoreComponents"
      end)

      assert_file("phx_blog/lib/phx_blog_web/components/layouts.ex", fn file ->
        assert file =~ "defmodule PhxBlogWeb.Layouts"
      end)

      assert_file("phx_blog/lib/phx_blog_web/router.ex", fn file ->
        assert file =~ "defmodule PhxBlogWeb.Router"
        assert file =~ "live_dashboard"
        assert file =~ "import Phoenix.LiveDashboard.Router"
      end)

      assert_file("phx_blog/lib/phx_blog_web/endpoint.ex", fn file ->
        assert file =~ ~s|defmodule PhxBlogWeb.Endpoint|
        assert file =~ ~s|socket "/live"|
        assert file =~ ~s|plug Phoenix.LiveDashboard.RequestLogger|
      end)

      assert_file("phx_blog/lib/phx_blog_web/components/layouts/root.html.heex", fn file ->
        assert file =~ ~s|<meta name="csrf-token" content={get_csrf_token()} />|
      end)

      assert_file("phx_blog/lib/phx_blog_web/components/layouts/app.html.heex")
      assert_file("phx_blog/lib/phx_blog_web/controllers/page_html/home.html.heex")

      # assets
      assert_file("phx_blog/.gitignore", fn file ->
        assert file =~ "/priv/static/assets/"
        assert file =~ "phx_blog-*.tar"
        assert file =~ ~r/\n$/
      end)

      assert_file("phx_blog/config/dev.exs", fn file ->
        assert file =~ "esbuild: {Esbuild,"
        assert file =~ "lib/phx_blog_web/(controllers|live|components)/.*(ex|heex)"
      end)

      # tailwind
      assert_file("phx_blog/assets/css/app.css")
      assert_file("phx_blog/assets/tailwind.config.js")
      assert_file("phx_blog/priv/hero_icons/LICENSE.md")
      assert_file("phx_blog/priv/hero_icons/UPGRADE.md")
      assert_file("phx_blog/priv/hero_icons/optimized/24/outline/cake.svg")
      assert_file("phx_blog/priv/hero_icons/optimized/24/solid/cake.svg")
      assert_file("phx_blog/priv/hero_icons/optimized/20/solid/cake.svg")

      refute File.exists?("phx_blog/priv/static/assets/app.css")
      refute File.exists?("phx_blog/priv/static/assets/app.js")
      assert File.exists?("phx_blog/assets/vendor")

      assert_file("phx_blog/config/config.exs", fn file ->
        assert file =~ "cd: Path.expand(\"../assets\", __DIR__)"
        assert file =~ "config :esbuild"
      end)

      # Ecto
      config = ~r/config :phx_blog, PhxBlog.Repo,/

      assert_file("phx_blog/mix.exs", fn file ->
        assert file =~ "{:phoenix_ecto,"
        assert file =~ "aliases: aliases()"
        assert file =~ "ecto.setup"
        assert file =~ "ecto.reset"
      end)

      assert_file("phx_blog/config/dev.exs", config)
      assert_file("phx_blog/config/test.exs", config)

      assert_file("phx_blog/config/runtime.exs", fn file ->
        assert file =~ config

        assert file =~
                 ~S|maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []|

        assert file =~ ~S|socket_options: maybe_ipv6|

        assert file =~ """
               if System.get_env("PHX_SERVER") do
                 config :phx_blog, PhxBlogWeb.Endpoint, server: true
               end
               """

        assert file =~ ~S[host = System.get_env("PHX_HOST") || "example.com"]
        assert file =~ ~S|url: [host: host, port: 443, scheme: "https"],|
      end)

      assert_file(
        "phx_blog/config/test.exs",
        ~R/database: "phx_blog_test#\{System.get_env\("MIX_TEST_PARTITION"\)\}"/
      )

      assert_file("phx_blog/lib/phx_blog/repo.ex", ~r"defmodule PhxBlog.Repo")
      assert_file("phx_blog/lib/phx_blog_web.ex", ~r"defmodule PhxBlogWeb")

      assert_file(
        "phx_blog/lib/phx_blog_web/endpoint.ex",
        ~r"plug Phoenix.Ecto.CheckRepoStatus, otp_app: :phx_blog"
      )

      assert_file("phx_blog/priv/repo/seeds.exs", ~r"PhxBlog.Repo.insert!")
      assert_file("phx_blog/test/support/data_case.ex", ~r"defmodule PhxBlog.DataCase")
      assert_file("phx_blog/priv/repo/migrations/.formatter.exs", ~r"import_deps: \[:ecto_sql\]")

      # LiveView
      refute_file("phx_blog/lib/phx_blog_web/live/page_live_view.ex")

      assert_file("phx_blog/assets/js/app.js", fn file ->
        assert file =~ ~s|import {LiveSocket} from "phoenix_live_view"|
        assert file =~ ~s|liveSocket.connect()|
      end)

      assert_file("phx_blog/mix.exs", fn file ->
        assert file =~ ~r":phoenix_live_view"
        assert file =~ ~r":floki"
      end)

      assert_file(
        "phx_blog/lib/phx_blog_web/router.ex",
        &assert(&1 =~ ~s[plug :fetch_live_flash])
      )

      assert_file("phx_blog/lib/phx_blog_web/router.ex", &assert(&1 =~ ~s[plug :put_root_layout]))
      assert_file("phx_blog/lib/phx_blog_web/router.ex", &assert(&1 =~ ~s[PageController]))

      # Telemetry
      assert_file("phx_blog/mix.exs", fn file ->
        assert file =~ "{:telemetry_metrics,"
        assert file =~ "{:telemetry_poller,"
      end)

      assert_file("phx_blog/lib/phx_blog_web/telemetry.ex", fn file ->
        assert file =~ "defmodule PhxBlogWeb.Telemetry do"
        assert file =~ "{:telemetry_poller, measurements: periodic_measurements()"
        assert file =~ "defp periodic_measurements do"
        assert file =~ "# {PhxBlogWeb, :count_users, []}"
        assert file =~ "def metrics do"
        assert file =~ "summary(\"phoenix.endpoint.stop.duration\","
        assert file =~ "summary(\"phoenix.router_dispatch.stop.duration\","
        assert file =~ "# Database Metrics"
        assert file =~ "summary(\"phx_blog.repo.query.total_time\","
      end)

      # Mailer
      assert_file("phx_blog/mix.exs", fn file ->
        assert file =~ "{:swoosh, \"~> 1.3\"}"
        assert file =~ "{:finch, \"~> 0.13\"}"
      end)

      assert_file("phx_blog/lib/phx_blog/application.ex", fn file ->
        assert file =~ "{Finch, name: PhxBlog.Finch}"
      end)

      assert_file("phx_blog/lib/phx_blog/mailer.ex", fn file ->
        assert file =~ "defmodule PhxBlog.Mailer do"
        assert file =~ "use Swoosh.Mailer, otp_app: :phx_blog"
      end)

      assert_file("phx_blog/config/config.exs", fn file ->
        assert file =~ "config :phx_blog, PhxBlog.Mailer, adapter: Swoosh.Adapters.Local"
      end)

      assert_file("phx_blog/config/test.exs", fn file ->
        assert file =~ "config :swoosh"
        assert file =~ "config :phx_blog, PhxBlog.Mailer, adapter: Swoosh.Adapters.Test"
      end)

      assert_file("phx_blog/config/dev.exs", fn file ->
        assert file =~ "config :swoosh"
      end)

      assert_file("phx_blog/config/prod.exs", fn file ->
        assert file =~
                 "config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: PhxBlog.Finch"
      end)

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
      assert msg =~ "$ cd phx_blog"
      assert msg =~ "$ mix deps.get"

      assert_received {:mix_shell, :info, ["Then configure your database in config/dev.exs" <> _]}
      assert_received {:mix_shell, :info, ["Start your Phoenix app" <> _]}

      # Gettext
      assert_file("phx_blog/lib/phx_blog_web/gettext.ex", ~r"defmodule PhxBlogWeb.Gettext")
      assert File.exists?("phx_blog/priv/gettext/errors.pot")
      assert File.exists?("phx_blog/priv/gettext/en/LC_MESSAGES/errors.po")
    end)
  end

  test "new without defaults" do
    in_tmp("new without defaults", fn ->
      Mix.Tasks.Phx.New.run([
        @app_name,
        "--no-html",
        "--no-assets",
        "--no-ecto",
        "--no-gettext",
        "--no-dashboard",
        "--no-mailer"
      ])

      # No assets
      assert_file("phx_blog/.gitignore", fn file ->
        refute file =~ "/priv/static/assets/"
        assert file =~ ~r/\n$/
      end)

      assert_file("phx_blog/config/dev.exs", ~r/watchers: \[\]/)

      # No assets & No HTML
      refute_file("phx_blog/priv/static/assets/app.css")
      refute_file("phx_blog/priv/static/favicon.ico")
      refute_file("phx_blog/priv/static/assets/app.js")

      # No Ecto
      config = ~r/config :phx_blog, PhxBlog.Repo,/
      refute File.exists?("phx_blog/lib/phx_blog/repo.ex")

      assert_file("phx_blog/lib/phx_blog_web/endpoint.ex", fn file ->
        refute file =~ "plug Phoenix.Ecto.CheckRepoStatus, otp_app: :phx_blog"
      end)

      assert_file("phx_blog/lib/phx_blog_web/telemetry.ex", fn file ->
        refute file =~ "# Database Metrics"
        refute file =~ "summary(\"phx_blog.repo.query.total_time\","
      end)

      assert_file("phx_blog/.formatter.exs", fn file ->
        assert file =~ "import_deps: [:phoenix]"
        assert file =~ "inputs: [\"*.{ex,exs}\", \"{config,lib,test}/**/*.{ex,exs}\"]"
        refute file =~ "subdirectories:"
      end)

      assert_file("phx_blog/mix.exs", &refute(&1 =~ ~r":phoenix_ecto"))

      assert_file("phx_blog/config/config.exs", fn file ->
        refute file =~ "config :esbuild"
        refute file =~ "config :phx_blog, :generators"
        refute file =~ "ecto_repos:"
      end)

      assert_file("phx_blog/config/dev.exs", fn file ->
        refute file =~ config
        assert file =~ "config :phoenix, :plug_init_mode, :runtime"
      end)

      assert_file("phx_blog/config/test.exs", &refute(&1 =~ config))
      assert_file("phx_blog/config/runtime.exs", &refute(&1 =~ config))
      assert_file("phx_blog/lib/phx_blog_web.ex", &refute(&1 =~ ~r"alias PhxBlog.Repo"))

      # No gettext
      refute_file("phx_blog/lib/phx_blog_web/gettext.ex")
      refute_file("phx_blog/priv/gettext/en/LC_MESSAGES/errors.po")
      refute_file("phx_blog/priv/gettext/errors.pot")
      assert_file("phx_blog/mix.exs", &refute(&1 =~ ~r":gettext"))
      assert_file("phx_blog/lib/phx_blog_web.ex", &refute(&1 =~ ~r"import AmsMockWeb.Gettext"))
      assert_file("phx_blog/config/dev.exs", &refute(&1 =~ ~r"gettext"))

      # No HTML
      assert File.exists?("phx_blog/test/phx_blog_web/controllers")

      assert File.exists?("phx_blog/lib/phx_blog_web/controllers")

      refute File.exists?("phx_blog/test/web/controllers/pager_controller_test.exs")
      refute File.exists?("phx_blog/lib/phx_blog_web/controllers/page_controller.ex")
      refute File.exists?("phx_blog/lib/phx_blog_web/controllers/page_html")
      refute File.exists?("phx_blog/lib/phx_blog_web/controllers/error_html.ex")
      refute File.exists?("phx_blog/lib/phx_blog_web/components")

      assert_file("phx_blog/mix.exs", &refute(&1 =~ ~r":phoenix_html"))
      assert_file("phx_blog/mix.exs", &refute(&1 =~ ~r":phoenix_live_reload"))

      assert_file("phx_blog/lib/phx_blog_web.ex", fn file ->
        refute file =~ "html_helpers"
        refute file =~ "Phoenix.HTML"
        refute file =~ "Phoenix.LiveView"
      end)

      assert_file("phx_blog/lib/phx_blog_web/endpoint.ex", fn file ->
        refute file =~ ~r"Phoenix.LiveReloader"
        refute file =~ ~r"Phoenix.LiveReloader.Socket"
      end)

      refute_file("phx_blog/lib/phx_blog_web/controllers/error_html.ex")
      assert_file("phx_blog/lib/phx_blog_web/controllers/error_json.ex")
      assert_file("phx_blog/lib/phx_blog_web/router.ex", &refute(&1 =~ ~r"pipeline :browser"))

      # No Dashboard
      assert_file("phx_blog/lib/phx_blog_web/endpoint.ex", fn file ->
        refute file =~ ~s|plug Phoenix.LiveDashboard.RequestLogger|
      end)

      assert_file("phx_blog/lib/phx_blog_web/router.ex", fn file ->
        refute file =~ "live_dashboard"
        refute file =~ "import Phoenix.LiveDashboard.Router"
      end)

      # No mailer or emails
      assert_file("phx_blog/mix.exs", fn file ->
        refute file =~ "{:swoosh, \"~> 1.3\"}"
        refute file =~ "{:finch, \"~> 0.13\"}"
      end)

      assert_file("phx_blog/lib/phx_blog/application.ex", fn file ->
        refute file =~ "{Finch, name: PhxBlog.Finch"
      end)

      refute File.exists?("phx_blog/lib/phx_blog/mailer.ex")

      assert_file("phx_blog/config/config.exs", fn file ->
        refute file =~ "config :swoosh"
        refute file =~ "config :phx_blog, PhxBlog.Mailer, adapter: Swoosh.Adapters.Local"
      end)

      assert_file("phx_blog/config/test.exs", fn file ->
        refute file =~ "config :swoosh"
        refute file =~ "config :phx_blog, PhxBlog.Mailer, adapter: Swoosh.Adapters.Test"
      end)

      assert_file("phx_blog/config/dev.exs", fn file ->
        refute file =~ "config :swoosh"
      end)

      assert_file("phx_blog/config/prod.exs", fn file ->
        refute file =~ "config :swoosh"
      end)
    end)
  end

  test "new with --no-dashboard" do
    in_tmp("new with no_dashboard", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--no-dashboard"])

      assert_file("phx_blog/mix.exs", &refute(&1 =~ ~r":phoenix_live_dashboard"))

      assert_file("phx_blog/lib/phx_blog_web/components/layouts/app.html.heex", fn file ->
        refute file =~ ~s|LiveDashboard|
      end)

      assert_file("phx_blog/lib/phx_blog_web/endpoint.ex", fn file ->
        assert file =~ ~s|defmodule PhxBlogWeb.Endpoint|
        assert file =~ ~s|  socket "/live"|
        refute file =~ ~s|plug Phoenix.LiveDashboard.RequestLogger|
      end)
    end)
  end

  test "new with --no-dashboard and --no-live" do
    in_tmp("new with no_dashboard and no_live", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--no-dashboard", "--no-live"])

      assert_file("phx_blog/lib/phx_blog_web/endpoint.ex", fn file ->
        assert file =~ ~s|defmodule PhxBlogWeb.Endpoint|
        assert file =~ ~s|# socket "/live"|
        refute file =~ ~s|plug Phoenix.LiveDashboard.RequestLogger|
      end)
    end)
  end

  test "new with --no-html" do
    in_tmp("new with no_html", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--no-html"])

      assert_file("phx_blog/mix.exs", fn file ->
        refute file =~ ~s|:phoenix_live_view|
        refute file =~ ~s|:phoenix_html|
        assert file =~ ~s|:phoenix_live_dashboard|
      end)

      assert_file("phx_blog/.formatter.exs", fn file ->
        assert file =~ "import_deps: [:ecto, :ecto_sql, :phoenix]"
        assert file =~ "subdirectories: [\"priv/*/migrations\"]"

        assert file =~
                 "inputs: [\"*.{ex,exs}\", \"{config,lib,test}/**/*.{ex,exs}\", \"priv/*/seeds.exs\"]"

        refute file =~ "plugins:"
      end)

      assert_file("phx_blog/lib/phx_blog_web/endpoint.ex", fn file ->
        assert file =~ ~s|defmodule PhxBlogWeb.Endpoint|
        assert file =~ ~s|socket "/live"|
        assert file =~ ~s|plug Phoenix.LiveDashboard.RequestLogger|
      end)

      assert_file("phx_blog/lib/phx_blog_web.ex", fn file ->
        refute file =~ ~s|Phoenix.HTML|
        refute file =~ ~s|Phoenix.LiveView|
      end)

      assert_file("phx_blog/lib/phx_blog_web/router.ex", fn file ->
        refute file =~ ~s|pipeline :browser|
        assert file =~ ~s|pipe_through [:fetch_session, :protect_from_forgery]|
      end)
    end)
  end

  test "new with --no-assets" do
    in_tmp("new no_assets", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--no-assets"])

      assert_file("phx_blog/.gitignore", fn file ->
        refute file =~ "/priv/static/assets/"
      end)

      assert_file("phx_blog/.gitignore")
      assert_file("phx_blog/.gitignore", ~r/\n$/)
      assert_file("phx_blog/priv/static/assets/app.css")
      assert_file("phx_blog/priv/static/assets/app.js")
      assert_file("phx_blog/priv/static/favicon.ico")

      assert_file("phx_blog/config/config.exs", fn file ->
        refute file =~ "config :esbuild"
      end)

      assert_file("phx_blog/config/prod.exs", fn file ->
        refute file =~ "config :phx_blog, PhxBlogWeb.Endpoint, cache_static_manifest:"
      end)
    end)
  end

  test "new with --no-ecto" do
    in_tmp("new with no_ecto", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--no-ecto"])

      assert_file("phx_blog/.formatter.exs", fn file ->
        assert file =~ "import_deps: [:phoenix]"
        assert file =~ "plugins: [Phoenix.LiveView.HTMLFormatter]"
        assert file =~ "inputs: [\"*.{heex,ex,exs}\", \"{config,lib,test}/**/*.{heex,ex,exs}\"]"
        refute file =~ "subdirectories:"
      end)
    end)
  end

  test "new with binary_id" do
    in_tmp("new with binary_id", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--binary-id"])
      assert_file("phx_blog/config/config.exs", ~r/generators: \[binary_id: true\]/)
    end)
  end

  test "new with uppercase" do
    in_tmp("new with uppercase", fn ->
      Mix.Tasks.Phx.New.run(["phxBlog"])

      assert_file("phxBlog/README.md")

      assert_file("phxBlog/mix.exs", fn file ->
        assert file =~ "app: :phxBlog"
      end)

      assert_file("phxBlog/config/dev.exs", fn file ->
        assert file =~ ~r/config :phxBlog, PhxBlog.Repo,/
        assert file =~ "database: \"phxblog_dev\""
      end)
    end)
  end

  test "new with path, app and module" do
    in_tmp("new with path, app and module", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--app", @app_name, "--module", "PhoteuxBlog"])

      assert_file("custom_path/.gitignore")
      assert_file("custom_path/.gitignore", ~r/\n$/)
      assert_file("custom_path/mix.exs", ~r/app: :phx_blog/)
      assert_file("custom_path/lib/phx_blog_web/endpoint.ex", ~r/app: :phx_blog/)
      assert_file("custom_path/config/config.exs", ~r/namespace: PhoteuxBlog/)
    end)
  end

  test "new inside umbrella" do
    in_tmp("new inside umbrella", fn ->
      File.write!("mix.exs", MixHelper.umbrella_mixfile_contents())
      File.mkdir!("apps")

      File.cd!("apps", fn ->
        Mix.Tasks.Phx.New.run([@app_name])

        assert_file("phx_blog/mix.exs", fn file ->
          assert file =~ "deps_path: \"../../deps\""
          assert file =~ "lockfile: \"../../mix.lock\""
        end)
      end)
    end)
  end

  test "new with --no-install" do
    in_tmp("new with no install", fn ->
      Mix.Tasks.Phx.New.run([@app_name, "--no-install"])

      # Does not prompt to install dependencies
      refute_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
      assert msg =~ "$ cd phx_blog"
      assert msg =~ "$ mix deps.get"

      assert_received {:mix_shell, :info, ["Then configure your database in config/dev.exs" <> _]}
      assert_received {:mix_shell, :info, ["Start your Phoenix app" <> _]}
    end)
  end

  test "new defaults to pg adapter" do
    in_tmp("new defaults to pg adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      Mix.Tasks.Phx.New.run([project_path])

      assert_file("custom_path/mix.exs", ":postgrex")

      assert_file("custom_path/config/dev.exs", [
        ~r/username: "postgres"/,
        ~r/password: "postgres"/,
        ~r/hostname: "localhost"/
      ])

      assert_file("custom_path/config/test.exs", [
        ~r/username: "postgres"/,
        ~r/password: "postgres"/,
        ~r/hostname: "localhost"/
      ])

      assert_file("custom_path/config/runtime.exs", [~r/url: database_url/])
      assert_file("custom_path/lib/custom_path/repo.ex", "Ecto.Adapters.Postgres")

      assert_file("custom_path/test/support/conn_case.ex", "DataCase.setup_sandbox(tags)")

      assert_file(
        "custom_path/test/support/data_case.ex",
        "Ecto.Adapters.SQL.Sandbox.start_owner"
      )
    end)
  end

  test "new with mysql adapter" do
    in_tmp("new with mysql adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--database", "mysql"])

      assert_file("custom_path/mix.exs", ":myxql")
      assert_file("custom_path/config/dev.exs", [~r/username: "root"/, ~r/password: ""/])
      assert_file("custom_path/config/test.exs", [~r/username: "root"/, ~r/password: ""/])
      assert_file("custom_path/config/runtime.exs", [~r/url: database_url/])
      assert_file("custom_path/lib/custom_path/repo.ex", "Ecto.Adapters.MyXQL")

      assert_file("custom_path/test/support/conn_case.ex", "DataCase.setup_sandbox(tags)")

      assert_file(
        "custom_path/test/support/data_case.ex",
        "Ecto.Adapters.SQL.Sandbox.start_owner"
      )
    end)
  end

  test "new with sqlite3 adapter" do
    in_tmp("new with sqlite3 adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--database", "sqlite3"])

      assert_file("custom_path/mix.exs", ":ecto_sqlite3")
      assert_file("custom_path/config/dev.exs", [~r/database: .*_dev.db/])
      assert_file("custom_path/config/test.exs", [~r/database: .*_test.db/])
      assert_file("custom_path/config/runtime.exs", [~r/database: database_path/])
      assert_file("custom_path/lib/custom_path/repo.ex", "Ecto.Adapters.SQLite3")

      assert_file("custom_path/test/support/conn_case.ex", "DataCase.setup_sandbox(tags)")

      assert_file(
        "custom_path/test/support/data_case.ex",
        "Ecto.Adapters.SQL.Sandbox.start_owner"
      )

      assert_file("custom_path/.gitignore", "*.db")
      assert_file("custom_path/.gitignore", "*.db-*")
    end)
  end

  test "new with mssql adapter" do
    in_tmp("new with mssql adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      Mix.Tasks.Phx.New.run([project_path, "--database", "mssql"])

      assert_file("custom_path/mix.exs", ":tds")

      assert_file("custom_path/config/dev.exs", [
        ~r/username: "sa"/,
        ~r/password: "some!Password"/
      ])

      assert_file("custom_path/config/test.exs", [
        ~r/username: "sa"/,
        ~r/password: "some!Password"/
      ])

      assert_file("custom_path/config/runtime.exs", [~r/url: database_url/])
      assert_file("custom_path/lib/custom_path/repo.ex", "Ecto.Adapters.Tds")

      assert_file("custom_path/test/support/conn_case.ex", "DataCase.setup_sandbox(tags)")

      assert_file(
        "custom_path/test/support/data_case.ex",
        "Ecto.Adapters.SQL.Sandbox.start_owner"
      )
    end)
  end

  test "new with invalid database adapter" do
    in_tmp("new with invalid database adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")

      assert_raise Mix.Error, ~s(Unknown database "invalid"), fn ->
        Mix.Tasks.Phx.New.run([project_path, "--database", "invalid"])
      end
    end)
  end

  test "new with invalid args" do
    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phx.New.run(["007invalid"])
    end

    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phx.New.run(["valid", "--app", "007invalid"])
    end

    assert_raise Mix.Error, ~r"Module name must be a valid Elixir alias", fn ->
      Mix.Tasks.Phx.New.run(["valid", "--module", "not.valid"])
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run(["string"])
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run(["valid", "--app", "mix"])
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Phx.New.run(["valid", "--module", "String"])
    end
  end

  test "invalid options" do
    assert_raise Mix.Error, ~r/Invalid option: -d/, fn ->
      Mix.Tasks.Phx.New.run(["valid", "-database", "mysql"])
    end
  end

  test "new without args" do
    in_tmp("new without args", fn ->
      assert capture_io(fn -> Mix.Tasks.Phx.New.run([]) end) =~
               "Creates a new Phoenix project."
    end)
  end
end
