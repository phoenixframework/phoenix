defmodule Mix.Tasks.Phx.New.Umbrella do
  use Mix.Tasks.Phx.New.Generator
  alias Mix.Tasks.Phx.New.{Project, Generator}

  template :new, [
    {:eex,  "phx_umbrella/config/config.exs", "config/config.exs"},
    {:eex,  "phx_umbrella/mix.exs",           "mix.exs"},
    {:eex,  "phx_umbrella/README.md",         "README.md"},
  ]


  def put_app(%Project{base_path: base_path} = project, opts) do
    app = opts[:app] || Path.basename(Path.expand(base_path))
    app_path = Path.join(base_path <> "_umbrella", "apps/#{app}")

    %Project{project |
             app: app,
             app_mod: Module.concat([opts[:module] || Macro.camelize(app)]),
             app_path: base_path,
             project_path: Path.expand(base_path)}
  end

  def put_root_app(%Project{app: app} = project, opts) when not is_nil(app) do
    %Project{project |
             root_app: :"#{app}_umbrella",
             root_mod: Module.concat(project.app_mod, Umbrella),
             root_path: project.project_path}
  end

  def put_web_app(%Project{app: app} = project, _opts) when not is_nil(app) do
    web_app = :"#{app}_web"

    %Project{project |
             web_app: web_app,
             web_namespace: Module.concat(project.app_mod, Web),
             web_path: Path.join(project_path, "apps/#{web_app}/")}
  end

  def gen_new(%Project{} = project) do
    if in_umbrella?(project.project_path) do
      Mix.raise "unable to nest umbrella project within apps"
    end
    copy_from project.project_path, __MODULE__, binding, template_files(:new)

    Generator.Web.gen_new(project)
    Generator.App.gen_new(project)
  end
end
