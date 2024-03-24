defmodule Phx.New.Web do
  @moduledoc false
  use Phx.New.Generator
  alias Phx.New.{Project}

  @pre "phx_umbrella/apps/app_name_web"

  template(:new, [
    {:prod_config, :project, "#{@pre}/config/runtime.exs": "config/runtime.exs"},
    {:config, :project,
     "#{@pre}/config/config.exs": "config/config.exs",
     "#{@pre}/config/dev.exs": "config/dev.exs",
     "#{@pre}/config/prod.exs": "config/prod.exs",
     "#{@pre}/config/test.exs": "config/test.exs"},
    {:keep, :web,
     "phx_web/controllers": "lib/:web_app/controllers",
     "phx_test/channels": "test/:web_app/channels",
     "phx_test/controllers": "test/:web_app/controllers"},
    {:eex, :web,
     "#{@pre}/lib/app_name.ex": "lib/:web_app.ex",
     "#{@pre}/lib/app_name/application.ex": "lib/:web_app/application.ex",
     "phx_web/endpoint.ex": "lib/:web_app/endpoint.ex",
     "phx_web/router.ex": "lib/:web_app/router.ex",
     "phx_web/telemetry.ex": "lib/:web_app/telemetry.ex",
     "phx_web/controllers/error_json.ex": "lib/:web_app/controllers/error_json.ex",
     "#{@pre}/mix.exs": "mix.exs",
     "#{@pre}/README.md": "README.md",
     "#{@pre}/gitignore": ".gitignore",
     "#{@pre}/test/test_helper.exs": "test/test_helper.exs",
     "phx_test/support/conn_case.ex": "test/support/conn_case.ex",
     "phx_test/controllers/error_json_test.exs": "test/:web_app/controllers/error_json_test.exs",
     "#{@pre}/formatter.exs": ".formatter.exs"}
  ])

  template(:gettext, [
    {:eex, :web,
     "phx_gettext/gettext.ex": "lib/:web_app/gettext.ex",
     "phx_gettext/en/LC_MESSAGES/errors.po": "priv/gettext/en/LC_MESSAGES/errors.po",
     "phx_gettext/errors.pot": "priv/gettext/errors.pot"}
  ])

  template(:html, [
    {:eex, :web,
     "phx_web/components/core_components.ex": "lib/:web_app/components/core_components.ex",
     "phx_web/components/layouts.ex": "lib/:web_app/components/layouts.ex",
     "phx_web/controllers/page_controller.ex": "lib/:web_app/controllers/page_controller.ex",
     "phx_web/controllers/error_html.ex": "lib/:web_app/controllers/error_html.ex",
     "phx_web/controllers/page_html.ex": "lib/:web_app/controllers/page_html.ex",
     "phx_web/controllers/page_html/home.html.heex":
       "lib/:web_app/controllers/page_html/home.html.heex",
     "phx_test/controllers/page_controller_test.exs":
       "test/:web_app/controllers/page_controller_test.exs",
     "phx_test/controllers/error_html_test.exs": "test/:web_app/controllers/error_html_test.exs",
     "phx_assets/topbar.js": "assets/vendor/topbar.js",
     "phx_web/components/layouts/root.html.heex": "lib/:web_app/components/layouts/root.html.heex",
     "phx_web/components/layouts/app.html.heex": "lib/:web_app/components/layouts/app.html.heex"},
    {:eex, :web, "phx_assets/logo.svg": "priv/static/images/logo.svg"}
  ])

  def prepare_project(%Project{app: app} = project) when not is_nil(app) do
    web_path = Path.expand(project.base_path)
    project_path = Path.dirname(Path.dirname(web_path))

    %Project{
      project
      | in_umbrella?: true,
        project_path: project_path,
        web_path: web_path,
        web_app: app,
        generators: [context_app: false],
        web_namespace: project.app_mod
    }
  end

  def generate(%Project{} = project) do
    inject_umbrella_config_defaults(project)
    copy_from(project, __MODULE__, :new)

    if Project.html?(project), do: gen_html(project)
    if Project.gettext?(project), do: gen_gettext(project)

    Phx.New.Single.gen_assets(project)
    project
  end

  defp gen_html(%Project{} = project) do
    copy_from(project, __MODULE__, :html)
  end

  defp gen_gettext(%Project{} = project) do
    copy_from(project, __MODULE__, :gettext)
  end
end
