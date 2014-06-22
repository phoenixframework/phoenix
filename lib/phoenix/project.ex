defmodule Phoenix.Project do

  def app do
    Keyword.get Mix.Project.config, :app
  end

  def module_root do
    app
    |> to_string
    |> Mix.Utils.camelize
    |> String.to_atom
  end

  def root_path do
    Module.concat([module_root]).module_info[:compile][:source]
    |> to_string
    |> Path.dirname
    |> Path.join("../")
    |> Path.expand
  end
end
