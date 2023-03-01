defmodule Phx.New.Single do
  @moduledoc false
  use Phx.New.Generator
  alias Phx.New.{Project}

  template(:new, [
    {:eex, :project,
     "phx_single/config/config.exs": "config/config.exs",
     "phx_single/config/dev.exs": "config/dev.exs",
     "phx_single/config/prod.exs": "config/prod.exs",
     "phx_single/config/runtime.exs": "config/runtime.exs",
     "phx_single/config/test.exs": "config/test.exs",
     "phx_single/lib/app_name/application.ex": "lib/:app/application.ex",
     "phx_single/lib/app_name.ex": "lib/:app.ex",
     "phx_web/controllers/error_json.ex": "lib/:lib_web_name/controllers/error_json.ex",
     "phx_web/endpoint.ex": "lib/:lib_web_name/endpoint.ex",
     "phx_web/router.ex": "lib/:lib_web_name/router.ex",
     "phx_web/telemetry.ex": "lib/:lib_web_name/telemetry.ex",
     "phx_single/lib/app_name_web.ex": "lib/:lib_web_name.ex",
     "phx_single/mix.exs": "mix.exs",
     "phx_single/README.md": "README.md",
     "phx_single/formatter.exs": ".formatter.exs",
     "phx_single/gitignore": ".gitignore",
     "phx_test/support/conn_case.ex": "test/support/conn_case.ex",
     "phx_single/test/test_helper.exs": "test/test_helper.exs",
     "phx_test/controllers/error_json_test.exs":
       "test/:lib_web_name/controllers/error_json_test.exs"},
    {:keep, :project,
     "phx_web/controllers": "lib/:lib_web_name/controllers",
     "phx_test/controllers": "test/:lib_web_name/controllers"}
  ])

  template(:gettext, [
    {:eex, :project,
     "phx_gettext/gettext.ex": "lib/:lib_web_name/gettext.ex",
     "phx_gettext/en/LC_MESSAGES/errors.po": "priv/gettext/en/LC_MESSAGES/errors.po",
     "phx_gettext/errors.pot": "priv/gettext/errors.pot"}
  ])

  template(:html, [
    {:eex, :project,
     "phx_web/controllers/error_html.ex": "lib/:lib_web_name/controllers/error_html.ex",
     "phx_test/controllers/error_html_test.exs":
       "test/:lib_web_name/controllers/error_html_test.exs",
     "phx_web/components/core_components.ex": "lib/:lib_web_name/components/core_components.ex",
     "phx_web/controllers/page_controller.ex": "lib/:lib_web_name/controllers/page_controller.ex",
     "phx_web/controllers/page_html.ex": "lib/:lib_web_name/controllers/page_html.ex",
     "phx_web/controllers/page_html/home.html.heex":
       "lib/:lib_web_name/controllers/page_html/home.html.heex",
     "phx_test/controllers/page_controller_test.exs":
       "test/:lib_web_name/controllers/page_controller_test.exs",
     "phx_web/components/layouts/root.html.heex":
       "lib/:lib_web_name/components/layouts/root.html.heex",
     "phx_web/components/layouts/app.html.heex":
       "lib/:lib_web_name/components/layouts/app.html.heex",
     "phx_web/components/layouts.ex": "lib/:lib_web_name/components/layouts.ex"},
    {:eex, :web, "phx_assets/topbar.js": "assets/vendor/topbar.js"}
  ])

  template(:ecto, [
    {:eex, :app,
     "phx_ecto/repo.ex": "lib/:app/repo.ex",
     "phx_ecto/formatter.exs": "priv/repo/migrations/.formatter.exs",
     "phx_ecto/seeds.exs": "priv/repo/seeds.exs",
     "phx_ecto/data_case.ex": "test/support/data_case.ex"},
    {:keep, :app, "phx_ecto/priv/repo/migrations": "priv/repo/migrations"}
  ])

  template(:assets, [
    {:eex, :web,
     "phx_assets/app.css": "assets/css/app.css",
     "phx_assets/app.js": "assets/js/app.js",
     "phx_assets/tailwind.config.js": "assets/tailwind.config.js"},
    {:keep, :web, "phx_assets/vendor": "assets/vendor"},
    {:eex, :web, "phx_assets/hero_icons/LICENSE.md": "priv/hero_icons/LICENSE.md"},
    {:eex, :web, "phx_assets/hero_icons/UPGRADE.md": "priv/hero_icons/UPGRADE.md"},
    {:zip, :web, "phx_assets/hero_icons/optimized.zip": "priv/hero_icons/optimized"}
  ])

  template(:no_assets, [
    {:text, :web,
     "phx_static/app.css": "priv/static/assets/app.css",
     "phx_static/app.js": "priv/static/assets/app.js"}
  ])

  template(:static, [
    {:text, :web,
     "phx_static/robots.txt": "priv/static/robots.txt",
     "phx_static/favicon.ico": "priv/static/favicon.ico"}
  ])

  template(:mailer, [
    {:eex, :app, "phx_mailer/lib/app_name/mailer.ex": "lib/:app/mailer.ex"}
  ])

  def prepare_project(%Project{app: app} = project) when not is_nil(app) do
    %Project{project | project_path: project.base_path}
    |> put_app()
    |> put_root_app()
    |> put_web_app()
  end

  defp put_app(%Project{base_path: base_path} = project) do
    %Project{project | in_umbrella?: in_umbrella?(base_path), app_path: base_path}
  end

  defp put_root_app(%Project{app: app, opts: opts} = project) do
    %Project{
      project
      | root_app: app,
        root_mod: Module.concat([opts[:module] || Macro.camelize(app)])
    }
  end

  defp put_web_app(%Project{app: app} = project) do
    %Project{
      project
      | web_app: app,
        lib_web_name: "#{app}_web",
        web_namespace: Module.concat(["#{project.root_mod}Web"]),
        web_path: project.project_path
    }
  end

  def generate(%Project{} = project) do
    copy_from(project, __MODULE__, :new)

    if Project.ecto?(project), do: gen_ecto(project)
    if Project.html?(project), do: gen_html(project)
    if Project.mailer?(project), do: gen_mailer(project)
    if Project.gettext?(project), do: gen_gettext(project)

    gen_assets(project)
    project
  end

  def gen_html(project) do
    copy_from(project, __MODULE__, :html)
  end

  def gen_gettext(project) do
    copy_from(project, __MODULE__, :gettext)
  end

  def gen_ecto(project) do
    copy_from(project, __MODULE__, :ecto)
    gen_ecto_config(project)
  end

  def gen_assets(%Project{} = project) do
    if Project.assets?(project) or Project.html?(project) do
      command = if Project.assets?(project), do: :assets, else: :no_assets
      copy_from(project, __MODULE__, command)
      copy_from(project, __MODULE__, :static)
    end
  end

  def gen_mailer(%Project{} = project) do
    copy_from(project, __MODULE__, :mailer)
  end
end
