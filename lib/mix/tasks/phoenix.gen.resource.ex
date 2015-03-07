defmodule Mix.Tasks.Phoenix.Gen.Resource do
  use Mix.Task
  alias Phoenix.Naming

  @shortdoc "Generates resource files"

  @moduledoc """
  Generates a Phoenix resource.

      mix phoenix.gen.resource User users name:string age:integer

  The first argument is the module name followed by
  its plural name (used for resources and schema).

  The generated resource will contain:

    * a model in web/models
    * a view in web/views
    * a controller in web/controllers
    * a migration file for the repository
    * default CRUD templates in web/templates

  ## Namespaced resources

  Resources can be namespaced, for such, it is just necessary
  to namespace the first argument of the generator:

      mix phoenix.gen.resource Admin.User admin_users name:string age:integer

  """
  def run([singular, plural|attrs]) do
    base     = Mix.Phoenix.base
    camelize = Naming.camelize(singular)
    path     = Naming.underscore(camelize)
    singular = String.split(path, "/") |> List.last
    module   = Module.concat(base, camelize) |> inspect
    alias    = Module.split(module) |> List.last
    route    = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")

    binding = [path: path, singular: singular, module: module,
               plural: plural, route: route, base: base, alias: alias]

    Mix.Phoenix.copy_from source_dir, "", binding, [
      {:eex, "model.ex",      "web/models/#{path}.ex"},
      {:eex, "view.ex",       "web/views/#{path}_view.ex"},
      {:eex, "controller.ex", "web/controllers/#{path}_controller.ex"},
    ]
  end

  def run(_) do
    Mix.raise """
    mix phoenix.gen.resource expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.resource User users name:string
    """
  end

  defp source_dir do
    Application.app_dir(:phoenix, "priv/templates/resource")
  end
end