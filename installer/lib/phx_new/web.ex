defmodule Phx.New.Web do
  @moduledoc false
  use Phx.New.Generator
  alias Phx.New.{Project}

  @pre "phx_umbrella/apps/app_name_web"

  template :new, [
    {:config, "#{@pre}/config/config.exs",            :project, "config/config.exs"},
    {:config, "#{@pre}/config/dev.exs",               :project, "config/dev.exs"},
    {:config, "#{@pre}/config/prod.exs",              :project, "config/prod.exs"},
    {:config, "#{@pre}/config/prod.secret.exs",       :project, "config/prod.secret.exs"},
    {:config, "#{@pre}/config/test.exs",              :project, "config/test.exs"},
    {:eex,  "#{@pre}/lib/app_name.ex",                :web, "lib/:web_app.ex"},
    {:eex,  "#{@pre}/lib/app_name/application.ex",    :web, "lib/:web_app/application.ex"},
    {:eex,  "phx_web/channels/user_socket.ex",        :web, "lib/:web_app/channels/user_socket.ex"},
    {:keep, "phx_web/controllers",                    :web, "lib/:web_app/controllers"},
    {:eex,  "phx_web/endpoint.ex",                    :web, "lib/:web_app/endpoint.ex"},
    {:eex,  "phx_web/router.ex",                      :web, "lib/:web_app/router.ex"},
    {:eex,  "phx_web/views/error_helpers.ex",         :web, "lib/:web_app/views/error_helpers.ex"},
    {:eex,  "phx_web/views/error_view.ex",            :web, "lib/:web_app/views/error_view.ex"},
    {:eex,  "#{@pre}/mix.exs",                        :web, "mix.exs"},
    {:eex,  "#{@pre}/README.md",                      :web, "README.md"},
    {:eex,  "#{@pre}/gitignore",                      :web, ".gitignore"},
    {:keep, "phx_test/channels",                      :web, "test/:web_app/channels"},
    {:keep, "phx_test/controllers",                   :web, "test/:web_app/controllers"},
    {:eex,  "#{@pre}/test/test_helper.exs",           :web, "test/test_helper.exs"},
    {:eex,  "phx_test/support/channel_case.ex",       :web, "test/support/channel_case.ex"},
    {:eex,  "phx_test/support/conn_case.ex",          :web, "test/support/conn_case.ex"},
    {:eex,  "phx_test/views/error_view_test.exs",     :web, "test/:web_app/views/error_view_test.exs"},
    {:eex,  "#{@pre}/formatter.exs",                  :web, ".formatter.exs"},
  ]

  template :gettext, [
    {:eex,  "phx_gettext/gettext.ex",               :web, "lib/:web_app/gettext.ex"},
    {:eex,  "phx_gettext/en/LC_MESSAGES/errors.po", :web, "priv/gettext/en/LC_MESSAGES/errors.po"},
    {:eex,  "phx_gettext/errors.pot",               :web, "priv/gettext/errors.pot"}
  ]

  template :html, [
    {:eex,  "phx_web/controllers/page_controller.ex",         :web, "lib/:web_app/controllers/page_controller.ex"},
    {:eex,  "phx_web/templates/layout/app.html.eex",          :web, "lib/:web_app/templates/layout/app.html.eex"},
    {:eex,  "phx_web/templates/page/index.html.eex",          :web, "lib/:web_app/templates/page/index.html.eex"},
    {:eex,  "phx_web/views/layout_view.ex",                   :web, "lib/:web_app/views/layout_view.ex"},
    {:eex,  "phx_web/views/page_view.ex",                     :web, "lib/:web_app/views/page_view.ex"},
    {:eex,  "phx_test/controllers/page_controller_test.exs",  :web, "test/:web_app/controllers/page_controller_test.exs"},
    {:eex,  "phx_test/views/layout_view_test.exs",            :web, "test/:web_app/views/layout_view_test.exs"},
    {:eex,  "phx_test/views/page_view_test.exs",              :web, "test/:web_app/views/page_view_test.exs"},
  ]

  template :live, [
    {:eex, "phx_live/templates/layout/root.html.leex", :web, "lib/:web_app/templates/layout/root.html.leex"},
    {:eex, "phx_live/templates/layout/app.html.leex",  :web, "lib/:web_app/templates/layout/app.html.leex"},
    {:eex, "phx_live/templates/layout/live.html.leex", :web, "lib/:web_app/templates/layout/live.html.leex"},
    {:eex, "phx_web/templates/page/index.html.eex",    :web, "lib/:web_app/templates/page/index.html.leex"},
    {:eex, "phx_web/views/layout_view.ex",             :web, "lib/:web_app/views/layout_view.ex"},
    {:eex, "phx_web/views/page_view.ex",               :web, "lib/:web_app/views/page_view.ex"},
    {:eex, "phx_live/live/page_live.ex",               :web, "lib/:web_app/live/page_live.ex"},
    {:eex, "phx_test/views/layout_view_test.exs",      :web, "test/:web_app/views/layout_view_test.exs"},
    {:eex, "phx_test/live/home_live_test.exs",         :web, "test/:web_app/live/home_live_test.exs"},
  ]

  def prepare_project(%Project{app: app} = project) when not is_nil(app) do
    web_path = Path.expand(project.base_path)
    project_path = Path.dirname(Path.dirname(web_path))

    %Project{project |
             in_umbrella?: true,
             project_path: project_path,
             web_path: web_path,
             web_app: app,
             generators: [context_app: false],
             web_namespace: project.app_mod}
  end

  def generate(%Project{} = project) do
    inject_umbrella_config_defaults(project)

    if Project.live?(project), do: Phx.New.Single.assert_live_switches!(project)

    copy_from project, __MODULE__, :new

    cond do
      Project.live?(project) -> gen_live(project)
      Project.html?(project) -> gen_html(project)
      true -> :noop
    end

    if Project.gettext?(project), do: gen_gettext(project)

    case {Project.webpack?(project), Project.html?(project)} do
      {true, _}      -> Phx.New.Single.gen_webpack(project)
      {false, true}  -> Phx.New.Single.gen_static(project)
      {false, false} -> Phx.New.Single.gen_bare(project)
    end

    project
  end

  defp gen_html(%Project{} = project) do
    copy_from project, __MODULE__, :html
  end

  defp gen_gettext(%Project{} = project) do
    copy_from project, __MODULE__, :gettext
  end

  defp gen_live(%Project{} = project) do
    copy_from project, __MODULE__, :live
  end
end
