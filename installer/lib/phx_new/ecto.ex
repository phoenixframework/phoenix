defmodule Phx.New.Ecto do
  @moduledoc false
  use Phx.New.Generator
  alias Phx.New.{Project}

  @pre "phx_umbrella/apps/app_name"

  template :new, [
    {:eex,  "#{@pre}/config/config.exs",           :app, "config/config.exs"},
    {:eex,  "#{@pre}/config/dev.exs",              :app, "config/dev.exs"},
    {:eex,  "#{@pre}/config/prod.exs",             :app, "config/prod.exs"},
    {:eex,  "#{@pre}/config/prod.secret.exs",      :app, "config/prod.secret.exs"},
    {:eex,  "#{@pre}/config/test.exs",             :app, "config/test.exs"},
    {:eex,  "#{@pre}/lib/app_name/application.ex", :app, "lib/:app/application.ex"},
    {:eex,  "#{@pre}/lib/app_name.ex",             :app, "lib/:app.ex"},
    {:eex,  "#{@pre}/test/test_helper.exs",        :app, "test/test_helper.exs"},
    {:eex,  "#{@pre}/README.md",                   :app, "README.md"},
    {:eex,  "#{@pre}/mix.exs",                     :app, "mix.exs"},
    {:eex,  "#{@pre}/gitignore",                   :app, ".gitignore"},
    {:eex,  "#{@pre}/formatter.exs",               :app, ".formatter.exs"},
  ]

  template :ecto, [
    {:eex,  "phx_ecto/repo.ex",              :app, "lib/:app/repo.ex"},
    {:keep, "phx_ecto/priv/repo/migrations", :app, "priv/repo/migrations"},
    {:eex,  "phx_ecto/seeds.exs",            :app, "priv/repo/seeds.exs"},
    {:eex,  "phx_ecto/data_case.ex",         :app, "test/support/data_case.ex"},
    {:eex,  "phx_ecto/formatter.exs",        :app, "priv/repo/migrations/.formatter.exs"},
  ]

  def prepare_project(%Project{} = project) do
    project_path = Path.expand(project.base_path)

    %Project{project |
             in_umbrella?: true,
             app_path: project_path,
             project_path: project_path}
  end

  def generate(%Project{} = project) do
    copy_from project, __MODULE__, :new
    if Project.ecto?(project), do: gen_ecto(project)

    project
  end

  defp gen_ecto(project) do
    copy_from project, __MODULE__, :ecto
    gen_ecto_config(project)
  end
end
