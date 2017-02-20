defmodule Mix.Phx do
  @moduledoc false

  def in_single?(path) do
    mixfile = Path.join(path, "mix.exs")
    apps_path = Path.join(path, "apps")

    File.exists?(mixfile) and not File.exists?(apps_path)
  end

  def in_umbrella?(app_path) do
    try do
      umbrella = Path.expand(Path.join [app_path, "..", ".."])
      File.exists?(Path.join(umbrella, "mix.exs")) &&
        Mix.Project.in_project(:umbrella_check, umbrella, fn _ ->
          path = Mix.Project.config[:apps_path]
          path && Path.expand(path) == Path.join(umbrella, "apps")
        end)
    catch
      _, _ -> false
    end
  end
end
