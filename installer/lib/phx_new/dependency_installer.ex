defmodule Phx.New.DependencyInstaller do
  @moduledoc false
  alias Phx.New.{Project}

  def install_webpack(install?, project, relative_app_path) do
    assets_path = Path.join(project.web_path || project.project_path, "assets")
    webpack_config = Path.join(assets_path, "webpack.config.js")

    maybe_cmd(project, "cd #{relative_app_path.(assets_path)} && npm install && node node_modules/webpack/bin/webpack.js --mode development",
              File.exists?(webpack_config), install? && System.find_executable("npm"))
  end

  def install_mix(project, install?) do
    maybe_cmd(project, "mix deps.get", true, install? && hex_available?())
  end

  def compile(project, mix_step) do
    compile =
        case mix_step do
          [] -> Task.async(fn -> rebar_available?() && cmd(project, "mix deps.compile") end)
          _  -> Task.async(fn -> :ok end)
        end
    Task.await(compile, :infinity)
  end

  defp hex_available? do
    Code.ensure_loaded?(Hex)
  end

  defp rebar_available? do
    Mix.Rebar.rebar_cmd(:rebar) && Mix.Rebar.rebar_cmd(:rebar3)
  end

  defp maybe_cmd(project, cmd, should_run?, can_run?) do
    cond do
      should_run? && can_run? ->
        cmd(project, cmd)
      should_run? ->
        ["$ #{cmd}"]
      true ->
        []
    end
  end

  defp cmd(%Project{} = project, cmd) do
    Mix.shell.info [:green, "* running ", :reset, cmd]
    case Mix.shell.cmd(cmd, cmd_opts(project)) do
      0 ->
        []
      _ ->
        ["$ #{cmd}"]
    end
  end

  defp cmd_opts(%Project{} = project) do
    if Project.verbose?(project) do
      []
    else
      [quiet: true]
    end
  end
end