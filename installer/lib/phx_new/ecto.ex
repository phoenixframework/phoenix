defmodule Phx.New.Ecto do
  @moduledoc false
  use Phx.New.Generator
  alias Phx.New.{Project}

  @pre "phx_umbrella/apps/app_name"

  template :new, [
    {:config, "#{@pre}/config/config.exs.eex",           :project, "config/config.exs"},
    {:eex,    "#{@pre}/lib/app_name/application.ex.eex", :app, "lib/:app/application.ex"},
    {:eex,    "#{@pre}/lib/app_name.ex.eex",             :app, "lib/:app.ex"},
    {:eex,    "#{@pre}/test/test_helper.exs.eex",        :app, "test/test_helper.exs"},
    {:eex,    "#{@pre}/README.md",                       :app, "README.md"},
    {:eex,    "#{@pre}/mix.exs.eex",                     :app, "mix.exs"},
    {:eex,    "#{@pre}/gitignore",                       :app, ".gitignore"},
    {:eex,    "#{@pre}/formatter.exs.eex",               :app, ".formatter.exs"},
  ]

  def prepare_project(%Project{} = project) do
    app_path = Path.expand(project.base_path)
    project_path = Path.dirname(Path.dirname(app_path))

    %Project{project |
             in_umbrella?: true,
             app_path: app_path,
             project_path: project_path}
  end

  def generate(%Project{} = project) do
    inject_umbrella_config_defaults(project)
    copy_from project, __MODULE__, :new
    if Project.ecto?(project), do: Phx.New.Single.gen_ecto(project)
    project
  end
end
