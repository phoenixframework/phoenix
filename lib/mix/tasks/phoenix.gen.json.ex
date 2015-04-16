defmodule Mix.Tasks.Phoenix.Gen.Json do
  use Mix.Task

  @shortdoc "Generates JSON files for a resource"

  @moduledoc """
  Generates a Phoenix resource.

      mix phoenix.gen.json User users name:string age:integer

  The first argument is the module name followed by
  its plural name (used for resources and schema).

  The generated resource will contain:

    * a model in web/models
    * a view in web/views
    * a controller in web/controllers
    * a migration file for the repository
    * test files for generated model and controller

  Read the documentation for `phoenix.gen.model` for more
  information on attributes and namespaced resources.
  """
  def run([singular, plural|attrs] = args) do
    if String.contains?(plural, ":"), do: raise_with_help
    Mix.Task.run "phoenix.gen.model", args

    attrs   = Mix.Phoenix.attrs(attrs)
    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]
    route   = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")
    binding = binding ++ [plural: plural, route: route, params: Mix.Phoenix.params(attrs)]

    Mix.Phoenix.copy_from source_dir, "", binding, [
      {:eex, "controller.ex",       "web/controllers/#{path}_controller.ex"},
      {:eex, "view.ex",             "web/views/#{path}_view.ex"},
      {:eex, "controller_test.exs", "test/controllers/#{path}_controller_test.exs"},
    ]

    Mix.shell.info """

    Add the resource to the proper scope in web/router.ex:

        resources "/#{route}", #{binding[:scoped]}Controller

    and then update your repository by running migrations:

        $ mix ecto.migrate
    """
  end

  def run(_) do
    raise_with_help
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.json expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.json User users name:string
    """
  end

  defp source_dir do
    Application.app_dir(:phoenix, "priv/templates/json")
  end
end
