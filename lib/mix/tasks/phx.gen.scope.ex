defmodule Mix.Tasks.Phx.Gen.Scope do
  @shortdoc "Generates a Scope datastructure to identify the caller of code path."

  @moduledoc """
  Generates a Scope datastructure to identify the caller of code path.

      $ mix phx.gen.scope

  """
  use Mix.Task

  @switches [
    skip_existing: :boolean
  ]

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.scope must be invoked from within your *_web application root directory"
      )
    end

    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)
    ctx_app = opts[:context_app] || Mix.Phoenix.context_app()
    app_namespace = Mix.Phoenix.base()
    web_namespace = app_namespace |> Mix.Phoenix.web_module() |> inspect()

    scope = %{
      context_app: ctx_app,
      otp_app: Mix.Phoenix.otp_app(),
      module: Module.concat(app_namespace, "Scope"),
      hook_module: Module.concat(web_namespace, "ScopeHook"),
      file: Mix.Phoenix.context_lib_path(ctx_app, "scope.ex"),
      hook_file: Mix.Phoenix.web_path(ctx_app, "scope_hook.ex")
    }

    files = [
      {:eex, "scope.ex", scope.file},
      {:eex, "scope_hook.ex", scope.hook_file}
    ]

    if opts[:skip_existing] && Enum.find(files, fn {_, _, file} -> File.exists?(file) end) do
      :noop
    else
      Mix.Phoenix.prompt_for_conflicts(files)
      copy_new_files(scope, files)
    end
  end

  def copy_new_files(scope, files) do
    paths = Mix.Phoenix.generator_paths()
    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.scope", [scope: scope], files)
  end
end
