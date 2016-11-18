defmodule Mix.Tasks.Phx.New.Web do
  use Mix.Task
  use Mix.Tasks.Phx.New.{Project, Generator}

  @app "phx_umbrella/apps/app_name"
  @web "phx_umbrella/apps/app_name_web"

  # TODO
  #
  # Umbrella => only base proj mix.exs and apps/, then delegates
  # gen_ecto and gen_web to phx.web and phx.ecto
  #
  # extract Umbrella web generation to Web task
  # extract Umbrella ecto generation to Ecto task
  #
  #

  template :new, [
    {:eex,  "phx_umbrella/config/config.exs",  "config/config.exs"},
    {:eex,  "phx_umbrella/mix.exs",            "mix.exs"},
    {:eex,  "phx_umbrella/README.md",          "README.md"},
    {:eex,  "#{@app}/config/config.exs",       "apps/app_name/config/config.exs"},
    {:eex,  "#{@app}/config/dev.exs",          "apps/app_name/config/dev.exs"},
    {:eex,  "#{@app}/config/prod.exs",         "apps/app_name/config/prod.exs"},
    {:eex,  "#{@app}/config/prod.secret.exs",  "apps/app_name/config/prod.secret.exs"},
    {:eex,  "#{@app}/config/test.exs",         "apps/app_name/config/test.exs"},
    {:eex,  "#{@app}/lib/application.ex",      "apps/app_name/lib/application.ex"},
    {:eex,  "#{@app}/test/test_helper.exs",    "apps/app_name/test/test_helper.exs"},
    {:eex,  "#{@app}/README.md",               "apps/app_name/README.md"},
    {:eex,  "#{@app}/mix.exs",                 "apps/app_name/mix.exs"},
    {:eex,  "#{@web}/config/config.exs",       "apps/app_name_web/config/config.exs"},
    {:eex,  "#{@web}/config/dev.exs",          "apps/app_name_web/config/dev.exs"},
    {:eex,  "#{@web}/config/prod.exs",         "apps/app_name_web/config/prod.exs"},
    {:eex,  "#{@web}/config/prod.secret.exs",  "apps/app_name_web/config/prod.secret.exs"},
    {:eex,  "#{@web}/config/test.exs",         "apps/app_name_web/config/test.exs"},
    {:eex,  "#{@web}/test/test_helper.exs",    "apps/app_name_web/test/test_helper.exs"},
    {:eex,  "#{@web}/lib/application.ex",      "apps/app_name_web/lib/application.ex"},
    {:eex,  "#{@web}/lib/web.ex",              "apps/app_name_web/lib/web.ex"},
    {:eex,  "#{@web}/lib/endpoint.ex",         "apps/app_name_web/lib/endpoint.ex"},
    {:eex,  "#{@web}/lib/gettext.ex",          "apps/app_name_web/lib/gettext.ex"},
    {:eex,  "#{@web}/lib/router.ex",           "apps/app_name_web/lib/router.ex"},
    {:eex,  "#{@web}/README.md",               "apps/app_name_web/README.md"},
    {:eex,  "#{@web}/mix.exs",                 "apps/app_name_web/mix.exs"},
    {:keep, "#{@web}/test/channels",                  "apps/app_name_web/test/channels"},
    {:keep, "#{@web}/test/controllers",               "apps/app_name_web/test/controllers"},
    {:eex,  "#{@web}/test/views/error_view_test.exs", "apps/app_name_web/test/views/error_view_test.exs"},
    {:eex,  "#{@web}/test/support/conn_case.ex",      "apps/app_name_web/test/support/conn_case.ex"},
    {:eex,  "#{@web}/test/support/channel_case.ex",   "apps/app_name_web/test/support/channel_case.ex"},
    {:eex,  "#{@web}/lib/channels/user_socket.ex",    "apps/app_name_web/lib/channels/user_socket.ex"},
    {:keep, "#{@web}/lib/controllers",                "apps/app_name_web/lib/controllers"},
    {:eex,  "#{@web}/lib/views/error_view.ex",        "apps/app_name_web/lib/views/error_view.ex"},
    {:eex,  "#{@web}/lib/views/error_helpers.ex",     "apps/app_name_web/lib/views/error_helpers.ex"},
    {:eex,  "#{@web}/priv/gettext/errors.pot",        "apps/app_name_web/priv/gettext/errors.pot"},
    {:eex,  "#{@web}/priv/gettext/en/LC_MESSAGES/errors.po", "apps/app_name_web/priv/gettext/en/LC_MESSAGES/errors.po"},
  ]

  template :brunch, [
    {:text, "assets/brunch/gitignore",       ".gitignore"},
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
    {:eex,  "#{@web}/test/controllers/page_controller_test.exs", "test/controllers/page_controller_test.exs"},
    {:eex,  "#{@web}/test/views/layout_view_test.exs",           "test/views/layout_view_test.exs"},
    {:eex,  "#{@web}/test/views/page_view_test.exs",             "test/views/page_view_test.exs"},
    {:eex,  "#{@web}/lib/controllers/page_controller.ex",        "lib/controllers/page_controller.ex"},
    {:eex,  "#{@web}/lib/templates/layout/app.html.eex",         "lib/templates/layout/app.html.eex"},
    {:eex,  "#{@web}/lib/templates/page/index.html.eex",         "lib/templates/page/index.html.eex"},
    {:eex,  "#{@web}/lib/views/layout_view.ex",                  "lib/views/layout_view.ex"},
    {:eex,  "#{@web}/lib/views/page_view.ex",                    "lib/views/page_view.ex"},
  ]

  template :bare, [
    {:text,   "static/bare/gitignore", ".gitignore"},
  ]

  template :static, [
    {:text,   "assets/bare/gitignore", ".gitignore"},
    {:text,   "assets/app.css",         "priv/static/css/app.css"},
    {:append, "assets/phoenix.css",     "priv/static/css/app.css"},
    {:text,   "assets/bare/app.js",     "priv/static/js/app.js"},
    {:text,   "assets/robots.txt",      "priv/static/robots.txt"},
  ]


  def run([path | args]) do
    Mix.raise "TODO"
    unless in_umbrella?(path) do
      Mix.raise "the web task can only be run within an umbrella's apps directory"
    end
  end

  def gen_new(%Project{web_path: web_path, binding: binding} = project) do
    copy_from web_path, __MODULE__, binding, template_files(:new)
    if Project.html?(project), do: gen_html(project)

    case {Project.brunch?(project), Project.html?(project)} do
      {true, _}      -> gen_brunch(project)
      {false, true}  -> gen_static(project)
      {false, false} -> gen_bare(project)
    end
    :ok
  end

  defp gen_html(%Project{web_path: web_path, binding: binding}) do
    copy_from web_path, __MODULE__, binding, template_files(:html)
  end

  defp gen_static(%Project{web_path: web_path, binding: binding}) do
    copy_from web_path, __MODULE__, binding, template_files(:static)
    create_file Path.join(web_path, "priv/static/js/phoenix.js"), phoenix_js_text()
    create_file Path.join(web_path, "priv/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(web_path, "priv/static/favicon.ico"), phoenix_favicon_text()
  end

  defp gen_brunch(%Project{web_path: web_path, binding: binding}) do
    copy_from web_path, __MODULE__, binding, template_files(:brunch)
    create_file Path.join(web_path, "assets/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(web_path, "assets/static/favicon.ico"), phoenix_favicon_text()
  end

  defp gen_bare(%Project{web_path: web_path, binding: binding}) do
    copy_from web_path, __MODULE__, binding, template_files(:bare)
  end
end
