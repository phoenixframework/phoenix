defmodule Mix.Tasks.Phx.New.Web do
  @moduledoc """
  Creates a new Phoenix web project within an umbrella application.

  It expects the name of the otp app as the first argument and
  for the command to be run inside your umbrella application's
  apps directory:

      $ cd my_umbrella/apps
      $ mix phx.new.web APP [--module MODULE] [--app APP]

  This task is inteded to create a bare Phoenix project without
  database integration, which interfaces with your greater
  umbrella application(s).

  ## Examples

      mix phx.new.web hello_web

  Is equivalent to:

      mix phx.new.web hello_web --module Hello.Web

  Supports the same options as the `phx.new` task.
  See `Mix.Tasks.Phx.New` for details.
  """
  use Mix.Task
  use Phx.New.Generator
  alias Phx.New.{Project}

  @pre "phx_umbrella/apps/app_name_web"

  template :new, [
    {:eex,  "#{@pre}/config/config.exs",              :web, "config/config.exs"},
    {:eex,  "#{@pre}/config/dev.exs",                 :web, "config/dev.exs"},
    {:eex,  "#{@pre}/config/prod.exs",                :web, "config/prod.exs"},
    {:eex,  "#{@pre}/config/prod.secret.exs",         :web, "config/prod.secret.exs"},
    {:eex,  "#{@pre}/config/test.exs",                :web, "config/test.exs"},
    {:eex,  "#{@pre}/test/test_helper.exs",           :web, "test/test_helper.exs"},
    {:eex,  "#{@pre}/lib/app_name/application.ex",    :web, "lib/:web_app/application.ex"},
    {:eex,  "#{@pre}/lib/app_name.ex",                :web, "lib/:web_app.ex"},
    {:eex,  "#{@pre}/lib/app_name/endpoint.ex",       :web, "lib/:web_app/endpoint.ex"},
    {:eex,  "#{@pre}/lib/app_name/gettext.ex",        :web, "lib/:web_app/gettext.ex"},
    {:eex,  "#{@pre}/lib/app_name/router.ex",         :web, "lib/:web_app/router.ex"},
    {:eex,  "#{@pre}/README.md",                      :web, "README.md"},
    {:eex,  "#{@pre}/mix.exs",                        :web, "mix.exs"},
    {:keep, "#{@pre}/test/channels",                  :web, "test/channels"},
    {:keep, "#{@pre}/test/controllers",               :web, "test/controllers"},
    {:eex,  "#{@pre}/test/views/error_view_test.exs", :web, "test/views/error_view_test.exs"},
    {:eex,  "#{@pre}/test/support/conn_case.ex",      :web, "test/support/conn_case.ex"},
    {:eex,  "#{@pre}/test/support/channel_case.ex",   :web, "test/support/channel_case.ex"},
    {:eex,  "#{@pre}/lib/app_name/channels/user_socket.ex",    :web, "lib/:web_app/channels/user_socket.ex"},
    {:keep, "#{@pre}/lib/app_name/controllers",                :web, "lib/:web_app/controllers"},
    {:eex,  "#{@pre}/lib/app_name/views/error_view.ex",        :web, "lib/:web_app/views/error_view.ex"},
    {:eex,  "#{@pre}/lib/app_name/views/error_helpers.ex",     :web, "lib/:web_app/views/error_helpers.ex"},
    {:eex,  "#{@pre}/priv/gettext/errors.pot",        :web, "priv/gettext/errors.pot"},
    {:eex,  "#{@pre}/priv/gettext/en/LC_MESSAGES/errors.po", :web, "priv/gettext/en/LC_MESSAGES/errors.po"},
  ]

  template :brunch, [
    {:text, "assets/brunch/gitignore",        :web, ".gitignore"},
    {:eex,  "assets/brunch/brunch-config.js", :web, "assets/brunch-config.js"},
    {:eex,  "assets/brunch/package.json",     :web, "assets/package.json"},
    {:text, "assets/app.css",                 :web, "assets/css/app.css"},
    {:text, "assets/phoenix.css",             :web, "assets/css/phoenix.css"},
    {:eex,  "assets/brunch/app.js",           :web, "assets/js/app.js"},
    {:eex,  "assets/brunch/socket.js",        :web, "assets/js/socket.js"},
    {:keep, "assets/vendor",                  :web, "assets/vendor"},
    {:text, "assets/robots.txt",              :web, "assets/static/robots.txt"},
  ]

  template :html, [
    {:eex,  "#{@pre}/test/controllers/page_controller_test.exs",   :web, "test/controllers/page_controller_test.exs"},
    {:eex,  "#{@pre}/test/views/layout_view_test.exs",             :web, "test/views/layout_view_test.exs"},
    {:eex,  "#{@pre}/test/views/page_view_test.exs",               :web, "test/views/page_view_test.exs"},
    {:eex,  "#{@pre}/lib/app_name/controllers/page_controller.ex", :web, "lib/:web_app/controllers/page_controller.ex"},
    {:eex,  "#{@pre}/lib/app_name/templates/layout/app.html.eex",  :web, "lib/:web_app/templates/layout/app.html.eex"},
    {:eex,  "#{@pre}/lib/app_name/templates/page/index.html.eex",  :web, "lib/:web_app/templates/page/index.html.eex"},
    {:eex,  "#{@pre}/lib/app_name/views/layout_view.ex",           :web, "lib/:web_app/views/layout_view.ex"},
    {:eex,  "#{@pre}/lib/app_name/views/page_view.ex",             :web, "lib/:web_app/views/page_view.ex"},
  ]

  template :bare, [
    {:text, "assets/bare/gitignore", :web, ".gitignore"},
  ]

  template :static, [
    {:text,   "assets/bare/gitignore", :web, ".gitignore"},
    {:text,   "assets/app.css",        :web, "priv/static/css/app.css"},
    {:append, "assets/phoenix.css",    :web, "priv/static/css/app.css"},
    {:text,   "assets/bare/app.js",    :web, "priv/static/js/app.js"},
    {:text,   "assets/robots.txt",     :web, "priv/static/robots.txt"},
  ]


  def run([path | _] = args) do
    unless in_umbrella?(path) do
      Mix.raise "the web task can only be run within an umbrella's apps directory"
    end

    Mix.Tasks.Phx.New.run(args, __MODULE__)
  end

  def prepare_project(%Project{app: app} = project) when not is_nil(app) do
    project_path = Path.expand(project.base_path)

    %Project{project |
             in_umbrella?: true,
             project_path: project_path,
             web_path: project_path,
             web_app: app,
             web_namespace: project.app_mod}
  end

  def generate(%Project{} = project) do
    copy_from project, __MODULE__, template_files(:new)

    if Project.html?(project), do: gen_html(project)

    case {Project.brunch?(project), Project.html?(project)} do
      {true, _}      -> gen_brunch(project)
      {false, true}  -> gen_static(project)
      {false, false} -> gen_bare(project)
    end

    project
  end

  defp gen_html(%Project{} = project) do
    copy_from project, __MODULE__, template_files(:html)
  end

  defp gen_static(%Project{web_path: web_path} = project) do
    copy_from project, __MODULE__, template_files(:static)
    create_file Path.join(web_path, "priv/static/js/phoenix.js"), phoenix_js_text()
    create_file Path.join(web_path, "priv/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(web_path, "priv/static/favicon.ico"), phoenix_favicon_text()
  end

  defp gen_brunch(%Project{web_path: web_path} = project) do
    copy_from project, __MODULE__, template_files(:brunch)
    create_file Path.join(web_path, "assets/static/images/phoenix.png"), phoenix_png_text()
    create_file Path.join(web_path, "assets/static/favicon.ico"), phoenix_favicon_text()
  end

  defp gen_bare(%Project{} = project) do
    copy_from project, __MODULE__, template_files(:bare)
  end
end
