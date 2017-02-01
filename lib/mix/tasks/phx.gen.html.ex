defmodule Mix.Tasks.Phx.Gen.Html do
  use Mix.Task

  alias Mix.Phoenix.Context
  alias Mix.Tasks.Phx.Gen

  @shortdoc "TODO"

  @moduledoc """
  TODO
  """

  def run(args) do
    switches = [binary_id: :boolean, model: :boolean]
    {opts, parsed, _} = OptionParser.parse(args, switches: switches)
    [context_name, schema_name | schema_args] = validate_args!(parsed)

    schema = Gen.Schema.build([inspect(Module.concat(context_name, schema_name)) | schema_args])
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
