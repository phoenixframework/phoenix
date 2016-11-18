defmodule Mix.Tasks.Phx.New.App do
  use Mix.Task
  use Mix.Tasks.Phx.New.{Project, Generator}

  @prefix "phx_umbrella/apps/app_name"

  template :new, [
    {:eex, "#{@pre}/config/config.exs",      "apps/app_name/config/config.exs"},
    {:eex, "#{@pre}/config/dev.exs",         "apps/app_name/config/dev.exs"},
    {:eex, "#{@pre}/config/prod.exs",        "apps/app_name/config/prod.exs"},
    {:eex, "#{@pre}/config/prod.secret.exs", "apps/app_name/config/prod.secret.exs"},
    {:eex, "#{@pre}/config/test.exs",        "apps/app_name/config/test.exs"},
    {:eex, "#{@pre}/lib/application.ex",     "apps/app_name/lib/application.ex"},
    {:eex, "#{@pre}/test/test_helper.exs",   "apps/app_name/test/test_helper.exs"},
    {:eex, "#{@pre}/README.md",              "apps/app_name/README.md"},
    {:eex, "#{@pre}/mix.exs",                "apps/app_name/mix.exs"},
  ]

  template :ecto, [
    {:eex,  "#{@pre}/lib/repo.ex",          "lib/repo.ex"},
    {:keep, "#{@pre}/priv/repo/migrations", "priv/repo/migrations"},
    {:eex,  "phx_ecto/data_case.ex",        "test/support/data_case.ex"},
    {:eex,  "phx_ecto/seeds.exs",           "priv/repo/seeds.exs"},
  ]


  def run([path | args]) do
    Mix.raise "TODO"
    unless in_umbrella?(path) do
      Mix.raise "the ecto task can only be run within an umbrella's apps directory"
    end
  end

  def gen_new(%Project{} = project) do
    copy_from project.app_path, __MODULE__, project.binding, template_files(:new)
    if Project.ecto?(project), do: gen_ecto(project)
  end

  defp gen_ecto(project) do
    copy_from(project.app_path, __MODULE__, project.binding, template_files(:ecto))
    gen_ecto_config(project)
  end
end
