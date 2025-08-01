defmodule Phx.New.Umbrella do
  @moduledoc false
  use Phx.New.Generator
  alias Phx.New.{Ecto, Web, Project, Mailer}

  template(:new, [
    {:eex, :project,
     "phx_umbrella/gitignore": ".gitignore",
     "phx_umbrella/config/config.exs": "config/config.exs",
     "phx_umbrella/config/dev.exs": "config/dev.exs",
     "phx_umbrella/config/test.exs": "config/test.exs",
     "phx_umbrella/config/prod.exs": "config/prod.exs",
     "phx_umbrella/config/runtime.exs": "config/runtime.exs",
     "phx_umbrella/mix.exs": "mix.exs",
     "phx_umbrella/README.md": "README.md",
     "phx_umbrella/formatter.exs": ".formatter.exs"},
    {:config, :project, "phx_umbrella/config/extra_config.exs": "config/config.exs"}
  ])

  def prepare_project(%Project{app: app} = project) when not is_nil(app) do
    project
    |> put_app()
    |> put_web()
    |> put_root_app()
  end

  defp put_app(project) do
    project_path = Path.expand(project.base_path <> "_umbrella")
    app_path = Path.join(project_path, "apps/#{project.app}")

    %{project | in_umbrella?: true, app_path: app_path, project_path: project_path}
  end

  def put_web(%Project{app: app, opts: opts} = project) do
    web_app = :"#{app}_web"
    web_namespace = Module.concat([opts[:web_module] || "#{project.app_mod}Web"])

    %{
      project
      | web_app: web_app,
        lib_web_name: web_app,
        web_namespace: web_namespace,
        generators: [context_app: :"#{app}"],
        web_path: Path.join(project.project_path, "apps/#{web_app}/")
    }
  end

  defp put_root_app(%Project{app: app} = project) do
    %{
      project
      | root_app: :"#{app}_umbrella",
        root_mod: Module.concat(project.app_mod, "Umbrella")
    }
  end

  def generate(%Project{} = project) do
    if in_umbrella?(project.project_path) do
      Mix.raise("Unable to nest umbrella project within apps")
    end

    copy_from(project, __MODULE__, :new)

    generate_agents_md(project)

    project
    |> Web.generate()
    |> Ecto.generate()
    |> maybe_generate_mailer()
  end

  defp maybe_generate_mailer(project) do
    if Project.mailer?(project) do
      Mailer.generate(project)
    else
      project
    end
  end
end
