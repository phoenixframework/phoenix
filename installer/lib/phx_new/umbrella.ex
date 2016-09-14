defmodule Mix.Tasks.Phx.New.Umbrella do
  use Mix.Tasks.Phx.New.Generator

  template :new, [
    {:eex,  "phx_umbrella/config/config.exs",                     "config/config.exs"},
    {:eex,  "phx_umbrella/mix.exs",                               "mix.exs"},
    {:eex,  "phx_umbrella/README.md",                             "README.md"},
    {:eex,  "phx_umbrella/apps/app_name/config/config.exs",       "apps/app_name/config/config.exs"},
    {:eex,  "phx_umbrella/apps/app_name/config/dev.exs",          "apps/app_name/config/dev.exs"},
    {:eex,  "phx_umbrella/apps/app_name/config/prod.exs",         "apps/app_name/config/prod.exs"},
    {:eex,  "phx_umbrella/apps/app_name/config/prod.secret.exs",  "apps/app_name/config/prod.secret.exs"},
    {:eex,  "phx_umbrella/apps/app_name/config/test.exs",         "apps/app_name/config/test.exs"},
    {:eex,  "phx_umbrella/apps/app_name/lib/app_name.ex",         "apps/app_name/lib/app_name.ex"},
    {:eex,  "phx_umbrella/apps/app_name/test/test_helper.exs",    "apps/app_name/test/test_helper.exs"},
    {:eex,  "phx_umbrella/apps/app_name/README.md",               "apps/app_name/README.md"},
    {:eex,  "phx_umbrella/apps/app_name/mix.exs",                 "apps/app_name/mix.exs"},
    {:eex,  "phx_umbrella/apps/app_name_web/config/config.exs",       "apps/app_name_web/config/config.exs"},
    {:eex,  "phx_umbrella/apps/app_name_web/config/dev.exs",          "apps/app_name_web/config/dev.exs"},
    {:eex,  "phx_umbrella/apps/app_name_web/config/prod.exs",         "apps/app_name_web/config/prod.exs"},
    {:eex,  "phx_umbrella/apps/app_name_web/config/prod.secret.exs",  "apps/app_name_web/config/prod.secret.exs"},
    {:eex,  "phx_umbrella/apps/app_name_web/config/test.exs",         "apps/app_name_web/config/test.exs"},
    {:eex,  "phx_umbrella/apps/app_name_web/test/test_helper.exs",    "apps/app_name_web/test/test_helper.exs"},
    {:eex,  "phx_umbrella/apps/app_name_web/lib/app_name_web.ex",     "apps/app_name_web/lib/app_name_web.ex"},
    {:eex,  "phx_umbrella/apps/app_name_web/lib/endpoint.ex",         "apps/app_name_web/lib/endpoint.ex"},
    {:eex,  "phx_umbrella/apps/app_name_web/lib/gettext.ex",          "apps/app_name_web/lib/gettext.ex"},
    {:eex,  "phx_umbrella/apps/app_name_web/lib/router.ex",           "apps/app_name_web/lib/router.ex"},
    {:eex,  "phx_umbrella/apps/app_name_web/README.md",               "apps/app_name_web/README.md"},
    {:eex,  "phx_umbrella/apps/app_name_web/mix.exs",                 "apps/app_name_web/mix.exs"},
    {:keep, "phx_umbrella/apps/app_name_web/test/channels",                  "apps/app_name_web/test/channels"},
    {:keep, "phx_umbrella/apps/app_name_web/test/controllers",               "apps/app_name_web/test/controllers"},
    {:eex,  "phx_umbrella/apps/app_name_web/test/views/error_view_test.exs", "apps/app_name_web/test/views/error_view_test.exs"},
    {:eex,  "phx_umbrella/apps/app_name_web/test/support/conn_case.ex",      "apps/app_name_web/test/support/conn_case.ex"},
    {:eex,  "phx_umbrella/apps/app_name_web/test/support/channel_case.ex",   "apps/app_name_web/test/support/channel_case.ex"},
    {:eex,  "phx_umbrella/apps/app_name_web/lib/channels/user_socket.ex",    "apps/app_name_web/lib/channels/user_socket.ex"},
    {:keep, "phx_umbrella/apps/app_name_web/lib/controllers",                "apps/app_name_web/lib/controllers"},
    {:eex,  "phx_umbrella/apps/app_name_web/lib/views/error_view.ex",        "apps/app_name_web/lib/views/error_view.ex"},
    {:eex,  "phx_umbrella/apps/app_name_web/lib/views/error_helpers.ex",     "apps/app_name_web/lib/views/error_helpers.ex"},
    {:eex,  "phx_umbrella/apps/app_name_web/priv/gettext/errors.pot",        "apps/app_name_web/priv/gettext/errors.pot"},
    {:eex,  "phx_umbrella/apps/app_name_web/priv/gettext/en/LC_MESSAGES/errors.po", "apps/app_name_web/priv/gettext/en/LC_MESSAGES/errors.po"},
  ]

  template :ecto, [
    {:eex,  "phx_umbrella/apps/app_name/lib/repo.ex", "lib/repo.ex"},
    {:eex,  "phx_ecto/data_case.ex",                  "test/support/data_case.ex"},
    {:eex,  "phx_ecto/seeds.exs",                     "priv/repo/seeds.exs"},
    {:keep, "phx_umbrella/apps/app_name/priv/repo/migrations", "priv/repo/migrations"},
  ]

  template :brunch, [
    {:text, "assets/brunch/.gitignore",       ".gitignore"},
    {:eex,  "assets/brunch/brunch-config.js", "assets/brunch-config.js"},
    {:eex,  "assets/brunch/package.json",     "assets/package.json"},
    {:text, "assets/app.css",                 "assets/css/app.css"},
    {:text, "assets/phoenix.css",             "assets/css/phoenix.css"},
    {:eex,  "assets/brunch/app.js",           "assets/js/app.js"},
    {:eex,  "assets/brunch/socket.js",        "assets/js/socket.js"},
    {:keep, "assets/vendor",                  "assets/vendor"},
    {:text, "assets/robots.txt",              "assets/static/robots.txt"},
  ]

  template :html, [
    {:eex,  "phx_new/test/controllers/page_controller_test.exs",       "test/controllers/page_controller_test.exs"},
    {:eex,  "phx_new/test/views/layout_view_test.exs",                 "test/views/layout_view_test.exs"},
    {:eex,  "phx_new/test/views/page_view_test.exs",                   "test/views/page_view_test.exs"},
    {:eex,  "phx_new/lib/app_name/web/controllers/page_controller.ex", "lib/controllers/page_controller.ex"},
    {:eex,  "phx_new/lib/app_name/web/templates/layout/app.html.eex",  "lib/templates/layout/app.html.eex"},
    {:eex,  "phx_new/lib/app_name/web/templates/page/index.html.eex",  "lib/templates/page/index.html.eex"},
    {:eex,  "phx_new/lib/app_name/web/views/layout_view.ex",           "lib/views/layout_view.ex"},
    {:eex,  "phx_new/lib/app_name/web/views/page_view.ex",             "lib/views/page_view.ex"},
  ]

  template :bare, [
    {:text,   "static/bare/.gitignore", ".gitignore"},
  ]

  template :static, [
    {:text,   "assets/bare/.gitignore", ".gitignore"},
    {:text,   "assets/app.css",         "apps/app_name_web/priv/static/css/app.css"},
    {:append, "assets/phoenix.css",     "apps/app_name_web/priv/static/css/app.css"},
    {:text,   "assets/bare/app.js",     "apps/app_name_web/priv/static/js/app.js"},
    {:text,   "assets/robots.txt",      "apps/app_name_web/priv/static/robots.txt"},
  ]


  def app(base_path, opts) do
    app = opts[:app] || Path.basename(Path.expand(base_path))
    app_path = Path.join(base_path <> "_umbrella", "apps/#{app}")

    {app, Module.concat([opts[:module] || Macro.camelize(app)]), app_path}
  end

  def root_app(app_name, base_path, opts) do
    mod = opts[:module] || Macro.camelize(app_name)
    project_path = Path.expand(base_path) <> "_umbrella"

    {:"#{app_name}_umbrella", Module.concat(mod, Umbrella), project_path}
  end

  def web_app(app_name, project_path, opts) do
    mod = opts[:module] || Macro.camelize(app_name)
    web_app_name = :"#{app_name}_web"
    web_path = Path.join(project_path, "apps/#{web_app_name}/")

    {web_app_name, Module.concat(mod, Web), web_path}
  end

  def gen_new(path, binding) do
    copy_from path, __MODULE__, binding, template_files(:new)
  end

  def gen_html(web_path, binding) do
    copy_from web_path, __MODULE__, binding, template_files(:html)
  end

  def gen_ecto(app_path, binding) do
    copy_from(app_path, __MODULE__, binding, template_files(:ecto))
  end

  def gen_static(web_path, binding) do
    copy_from web_path, __MODULE__, binding, template_files(:static)
    create_file Path.join(web_path, "priv/static/js/phoenix.js"), phoenix_js_text()
    create_file Path.join(web_path, "priv/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(web_path, "priv/static/favicon.ico"), phoenix_favicon_text()
  end

  def gen_brunch(web_path, binding) do
    copy_from web_path, __MODULE__, binding, template_files(:brunch)
    create_file Path.join(web_path, "assets/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(web_path, "assets/static/favicon.ico"), phoenix_favicon_text()
  end

  def gen_bare(web_path, binding) do
    copy_from web_path, __MODULE__, binding, template_files(:bare)
  end
end
