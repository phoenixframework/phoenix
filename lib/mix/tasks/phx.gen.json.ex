defmodule Mix.Tasks.Phx.Gen.Json do
  @shortdoc "Generates controller, views, and bounded context for a JSON resource"

  @moduledoc """
  Generates controller, views, and bounded context for an JSON resource.

      mix phx.gen.json Accounts User users name:string age:integer

  The first argument is the context name followed by
  the schema module and its plural name (used for resources and schema).

  The above generated resource will contain:

    * a context module in lib/accounts.ex, serving as the API boundary
      to the resource
    * a schema in lib/accounts/user.ex, with an `accounts_users` table
    * a view in lib/web/views/user_view.ex
    * a controller in lib/web/controllers/user_controller.ex
    * a migration file for the repository
    * default CRUD templates in lib/web/templates/user
    * test files for generated context and controller features


  ## Schema table name

  By deault, the schema table name will be the plural name, namespaced by the
  context module name. You can customize this value by providing the `--table`
  option to the generator.

  Read the documentation for `phx.gen.schema` for more information on attributes
  and supported options.
  """
  use Mix.Task

  alias Mix.Phoenix.Context
  alias Mix.Tasks.Phx.Gen

  def run(args) do
    {context, schema} = Gen.Html.build(args)
    binding = [context: context, schema: schema]
    paths = Mix.Phoenix.generator_paths()

    context
    |> Context.inject_schema_access(binding, paths)
    |> copy_new_files(paths, binding)
    |> print_shell_instructions()
  end

  def copy_new_files(%Context{schema: schema} = context, paths, binding) do
    web_prefix = Gen.Html.web_prefix()
    test_prefix = Gen.Html.test_prefix()

    Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.json", "", binding, [
      {:eex, "controller.ex",       Path.join(web_prefix, "controllers/#{schema.singular}_controller.ex")},
      {:eex, "view.ex",             Path.join(web_prefix, "views/#{schema.singular}_view.ex")},
      {:eex, "controller_test.exs", Path.join(test_prefix, "controllers/#{schema.singular}_controller_test.exs")},
      {:new_eex, "changeset_view.ex", Path.join(web_prefix, "views/changeset_view.ex")},
      {:new_eex, "fallback_controller.ex", Path.join(web_prefix, "controllers/fallback_controller.ex")},
    ]

    Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.html", "", binding, [
     {:new_eex, "context_test.exs", "test/#{context.basename}_test.exs"}
    ]
    Gen.Schema.copy_new_files(schema, paths, binding)

    context
  end

  def print_shell_instructions(%Context{schema: schema}) do
    Mix.shell.info """

    Add the resource to your api scope in lib/web/router.ex:

        resources "/#{schema.plural}", #{inspect schema.alias}Controller, except: [:new, :edit]
    """
    Gen.Schema.print_shell_instructions(schema)
  end
end
