defmodule Mix.Tasks.Phx.Gen.Html do
  @shortdoc "Generates controller, views, and bounded context for an HTML resource"

  @moduledoc """
  Generates controller, views, and bounded context for an HTML resource.

      mix phx.gen.html Accounts User users name:string age:integer

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
    switches = [binary_id: :boolean, model: :boolean, table: :string]
    {opts, parsed, _} = OptionParser.parse(args, switches: switches)
    [context_name, schema_name, plural | schema_args] = validate_args!(parsed)

    table = Keyword.get(opts, :table, Phoenix.Naming.underscore(context_name) <> "_#{plural}")
    schema_module = inspect(Module.concat(context_name, schema_name))

    schema = Gen.Schema.build([schema_module, plural | schema_args] ++ ["--table", table])
    context = Context.new(context_name, schema, opts)
    Mix.Phoenix.check_module_name_availability!(context.module)
    binding = [context: context, schema: schema]
    paths = Mix.Phoenix.generator_paths()

    context
    |> Context.inject_schema_access(binding, paths)
    |> copy_new_files(paths, binding)
    |> print_shell_instructions()
  end

  def copy_new_files(%Context{schema: schema} = context, paths, binding) do
    Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.html", "", binding, [
      {:eex, "controller.ex",       "lib/web/controllers/#{schema.singular}_controller.ex"},
      {:eex, "edit.html.eex",       "lib/web/templates/#{schema.singular}/edit.html.eex"},
      {:eex, "form.html.eex",       "lib/web/templates/#{schema.singular}/form.html.eex"},
      {:eex, "index.html.eex",      "lib/web/templates/#{schema.singular}/index.html.eex"},
      {:eex, "new.html.eex",        "lib/web/templates/#{schema.singular}/new.html.eex"},
      {:eex, "show.html.eex",       "lib/web/templates/#{schema.singular}/show.html.eex"},
      {:eex, "view.ex",             "lib/web/views/#{schema.singular}_view.ex"},
      {:eex, "context_test.exs",    "test/#{context.basename}_test.exs"},
      {:eex, "controller_test.exs", "test/web/controllers/#{schema.singular}_controller_test.exs"},
    ]
    Gen.Schema.copy_new_files(schema, paths, binding)

    context
  end

  def print_shell_instructions(%Context{schema: schema}) do
    Mix.shell.info """

    Add the resource to your browser scope in lib/web/router.ex:

        resources "/#{schema.plural}", #{inspect schema.alias}Controller
    """
    Gen.Schema.print_shell_instructions(schema)
  end

  defp validate_args!([_, _, plural | _] = args) do
    cond do
      String.contains?(plural, ":") ->
        raise_with_help()
      plural != Phoenix.Naming.underscore(plural) ->
        Mix.raise "Expected the third argument, #{inspect plural}, to be all lowercase using snake_case convention"
      true ->
        args
    end
  end
  defp validate_args!(_) do
    raise_with_help()
  end

  @spec raise_with_help() :: no_return()
  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.html expects a context module name, followed by
    singular and plural names of the generated resource, ending with
    any number of attributes:

        mix phx.gen.html Accounts User users name:string
    """
  end
end
