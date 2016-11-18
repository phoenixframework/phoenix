defmodule Mix.Tasks.Phx.New.Single do
  use Mix.Tasks.Phx.New.Generator
  alias Mix.Tasks.Phx.New.{Project, Generator}

  template :new, [
    {:eex,  "phx_new/config/config.exs",               "config/config.exs"},
    {:eex,  "phx_new/config/dev.exs",                  "config/dev.exs"},
    {:eex,  "phx_new/config/prod.exs",                 "config/prod.exs"},
    {:eex,  "phx_new/config/prod.secret.exs",          "config/prod.secret.exs"},
    {:eex,  "phx_new/config/test.exs",                 "config/test.exs"},
    {:eex,  "phx_new/lib/application.ex",              "lib/application.ex"},
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
    {:eex,  "phx_new/lib/web/views/error_helpers.ex",  "lib/web/views/error_helpers.ex"},
    {:eex,  "phx_new/priv/gettext/en/LC_MESSAGES/errors.po",    "priv/gettext/en/LC_MESSAGES/errors.po"},
  ]

  template :ecto, [
    {:eex,  "phx_ecto/repo.ex",              "lib/repo.ex"},
    {:eex,  "phx_ecto/data_case.ex",         "test/support/data_case.ex"},
    {:keep, "phx_ecto/priv/repo/migrations", "priv/repo/migrations"},
    {:eex,  "phx_ecto/seeds.exs",            "priv/repo/seeds.exs"}
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
    {:text, "static/bare/gitignore", ".gitignore"},
  ]

  template :static, [
    {:text,   "assets/bare/gitignore", ".gitignore"},
    {:text,   "assets/app.css",         "priv/static/css/app.css"},
    {:append, "assets/phoenix.css",     "priv/static/css/app.css"},
    {:text,   "assets/bare/app.js",     "priv/static/js/app.js"},
    {:text,   "assets/robots.txt",      "priv/static/robots.txt"},
  ]

  def put_app(%Project{base_path: base_path} = project, opts) do
    app = opts[:app] || Path.basename(Path.expand(base_path))

    %Project{project |
             app: app,
             app_mod: Module.concat([opts[:module] || Macro.camelize(app)]),
             app_path: base_path,
             project_path: Path.expand(base_path)}
  end

  def put_root_app(%Project{app: app} = project, opts) when not is_nil(app) do
    %Project{project |
             root_app: app,
             root_mod: Module.concat([opts[:module] || Macro.camelize(app)])}
  end

  def put_web_app(%Project{app: app} = project, _opts) when not is_nil(app) do
    %Project{project |
             web_app: app,
             web_namespace: Module.concat(project.root_mod, Web)
             web_path: project.project_path}
  end

  def gen_new(%Project{} = project) do
    copy_from project.project_path, __MODULE__, project.binding, template_files(:new)

    if Project.ecto?(project), do: gen_ecto(project)
    if Project.html?(project), do: gen_html(project)

    case {Project.brunch?(project), Project.html?(project)} do
      {true, _}      -> gen_brunch(project)
      {false, true}  -> gen_static(project)
      {false, false} -> gen_bare(project)
    end

    project
  end

  defp gen_html(project) do
    copy_from project.web_path, __MODULE__, project.binding, template_files(:html)
  end

  defp gen_ecto(project) do
    copy_from project.app_path, __MODULE__, project.binding, template_files(:ecto)
    gen_ecto_config(project)
  end

  defp gen_static(%Project{web_path: path, binding: binding}) do
    copy_from path, __MODULE__, binding, template_files(:static)
    create_file Path.join(path, "priv/static/js/phoenix.js"), phoenix_js_text()
    create_file Path.join(path, "priv/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(path, "priv/static/favicon.ico"), phoenix_favicon_text()
  end

  defp gen_brunch(%Project{web_path: path, binding: binding}) do
    copy_from path, __MODULE__, binding, template_files(:brunch)
    create_file Path.join(path, "assets/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(path, "assets/static/favicon.ico"), phoenix_favicon_text()
  end

  defp gen_bare(%Project{web_path: path, binding: binding}) do
    copy_from path, __MODULE__, binding, template_files(:bare)
  end
end
