defmodule Mix.Tasks.Phx.New.Single do
  use Mix.Tasks.Phx.New.Generator

  template :new, [
    {:eex,  "phx_new/config/config.exs",               "config/config.exs"},
    {:eex,  "phx_new/config/dev.exs",                  "config/dev.exs"},
    {:eex,  "phx_new/config/prod.exs",                 "config/prod.exs"},
    {:eex,  "phx_new/config/prod.secret.exs",          "config/prod.secret.exs"},
    {:eex,  "phx_new/config/test.exs",                 "config/test.exs"},
    {:eex,  "phx_new/lib/app_name.ex",                 "lib/app_name.ex"},
    {:eex,  "phx_new/lib/web/endpoint.ex",             "lib/web/endpoint.ex"},
    {:keep, "phx_new/test/channels",                   "test/channels"},
    {:keep, "phx_new/test/controllers",                "test/controllers"},
    {:eex,  "phx_new/test/views/error_view_test.exs",  "test/views/error_view_test.exs"},
    {:eex,  "phx_new/test/support/conn_case.ex",       "test/support/conn_case.ex"},
    {:eex,  "phx_new/test/support/channel_case.ex",    "test/support/channel_case.ex"},
    {:eex,  "phx_new/test/test_helper.exs",            "test/test_helper.exs"},
    {:eex,  "phx_new/lib/web/channels/user_socket.ex", "lib/web/channels/user_socket.ex"},
    {:keep, "phx_new/lib/web/controllers",             "lib/web/controllers"},
    {:eex,  "phx_new/lib/web/router.ex",               "lib/web/router.ex"},
    {:eex,  "phx_new/lib/web/views/error_view.ex",     "lib/web/views/error_view.ex"},
    {:eex,  "phx_new/lib/web.ex",                      "lib/web.ex"},
    {:eex,  "phx_new/mix.exs",                         "mix.exs"},
    {:eex,  "phx_new/README.md",                       "README.md"},
    {:eex,  "phx_new/lib/gettext.ex",                  "lib/web/gettext.ex"},
    {:eex,  "phx_new/priv/gettext/errors.pot",         "priv/gettext/errors.pot"},
    {:eex,  "phx_new/priv/gettext/en/LC_MESSAGES/errors.po",    "priv/gettext/en/LC_MESSAGES/errors.po"},
    {:eex,  "phx_new/lib/web/views/error_helpers.ex",  "lib/web/views/error_helpers.ex"},
  ]

  template :ecto, [
    {:eex,  "phx_ecto/repo.ex",              "lib/repo.ex"},
    {:eex,  "phx_ecto/data_case.ex",         "test/support/data_case.ex"},
    {:keep, "phx_ecto/priv/repo/migrations", "priv/repo/migrations"},
    {:eex,  "phx_ecto/seeds.exs",            "priv/repo/seeds.exs"}
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
    {:eex, "phx_new/test/controllers/page_controller_test.exs", "test/controllers/page_controller_test.exs"},
    {:eex, "phx_new/test/views/layout_view_test.exs",           "test/views/layout_view_test.exs"},
    {:eex, "phx_new/test/views/page_view_test.exs",             "test/views/page_view_test.exs"},
    {:eex, "phx_new/lib/web/controllers/page_controller.ex",    "lib/web/controllers/page_controller.ex"},
    {:eex, "phx_new/lib/web/templates/layout/app.html.eex",     "lib/web/templates/layout/app.html.eex"},
    {:eex, "phx_new/lib/web/templates/page/index.html.eex",     "lib/web/templates/page/index.html.eex"},
    {:eex, "phx_new/lib/web/views/layout_view.ex",              "lib/web/views/layout_view.ex"},
    {:eex, "phx_new/lib/web/views/page_view.ex",                "lib/web/views/page_view.ex"},
  ]

  template :bare, [
    {:text, "static/bare/.gitignore", ".gitignore"},
  ]

  template :static, [
    {:text,   "assets/bare/.gitignore", ".gitignore"},
    {:text,   "assets/app.css",         "priv/static/css/app.css"},
    {:append, "assets/phoenix.css",     "priv/static/css/app.css"},
    {:text,   "assets/bare/app.js",     "priv/static/js/app.js"},
    {:text,   "assets/robots.txt",      "priv/static/robots.txt"},
  ]

  def app(base_path, opts) do
    app = opts[:app] || Path.basename(Path.expand(base_path))
    {app, Module.concat([opts[:module] || Macro.camelize(app)]), base_path}
  end

  def root_app(app_name, base_path, opts) do
    mod = Module.concat([opts[:module] || Macro.camelize(app_name)])
    {app_name, mod, Path.expand(base_path)}
  end

  def web_app(app_name, project_path, opts) do
    {_, mod, _} = root_app(app_name, project_path, opts)
    {app_name, Module.concat(mod, Web), project_path}
  end


  def gen_new(path, binding) do
    copy_from path, __MODULE__, binding, template_files(:new)
  end

  def gen_html(path, binding) do
    copy_from path, __MODULE__, binding, template_files(:html)
  end

  def gen_ecto(app_path, binding) do
    copy_from app_path, __MODULE__, binding, template_files(:ecto)
  end

  def gen_static(path, binding) do
    copy_from path, __MODULE__, binding, template_files(:static)
    create_file Path.join(path, "priv/static/js/phoenix.js"), phoenix_js_text()
    create_file Path.join(path, "priv/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(path, "priv/static/favicon.ico"), phoenix_favicon_text()
  end

  def gen_brunch(path, binding) do
    copy_from path, __MODULE__, binding, template_files(:brunch)
    create_file Path.join(path, "assets/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(path, "assets/static/favicon.ico"), phoenix_favicon_text()
  end

  def gen_bare(path, binding) do
    copy_from path, __MODULE__, binding, template_files(:bare)
  end
end
