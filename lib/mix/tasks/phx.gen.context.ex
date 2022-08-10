defmodule Mix.Tasks.Phx.Gen.Context do
  @shortdoc "Generates a context with functions around an Ecto schema"

  @moduledoc """
  Generates a context with functions around an Ecto schema.

      $ mix phx.gen.context Accounts User users name:string age:integer

  The first argument is the context module followed by the schema module
  and its plural name (used as the schema table name).

  The context is an Elixir module that serves as an API boundary for
  the given resource. A context often holds many related resources.
  Therefore, if the context already exists, it will be augmented with
  functions for the given resource.

  > Note: A resource may also be split
  > over distinct contexts (such as Accounts.User and Payments.User).

  The schema is responsible for mapping the database fields into an
  Elixir struct.

  Overall, this generator will add the following files to `lib/your_app`:

    * a context module in `accounts.ex`, serving as the API boundary
    * a schema in `accounts/user.ex`, with a `users` table

  A migration file for the repository and test files for the context
  will also be generated.

  ## Generating without a schema

  In some cases, you may wish to bootstrap the context module and
  tests, but leave internal implementation of the context and schema
  to yourself. Use the `--no-schema` flags to accomplish this.

  ## table

  By default, the table name for the migration and schema will be
  the plural name provided for the resource. To customize this value,
  a `--table` option may be provided. For example:

      $ mix phx.gen.context Accounts User users --table cms_users

  ## binary_id

  Generated migration can use `binary_id` for schema's primary key
  and its references with option `--binary-id`.

  ## Default options

  This generator uses default options provided in the `:generators`
  configuration of your application. These are the defaults:

      config :your_app, :generators,
        migration: true,
        binary_id: false,
        sample_binary_id: "11111111-1111-1111-1111-111111111111"

  You can override those options per invocation by providing corresponding
  switches, e.g. `--no-binary-id` to use normal ids despite the default
  configuration or `--migration` to force generation of the migration.

  Read the documentation for `phx.gen.schema` for more information on
  attributes.

  ## Skipping prompts

  This generator will prompt you if there is an existing context with the same
  name, in order to provide more instructions on how to correctly use phoenix contexts.
  You can skip this prompt and automatically merge the new schema access functions and tests into the
  existing context using `--merge-with-existing-context`. To prevent changes to
  the existing context and exit the generator, use `--no-merge-with-existing-context`.
  """

  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen

  @switches [binary_id: :boolean, table: :string, web: :string,
             schema: :boolean, context: :boolean, context_app: :string,
             merge_with_existing_context: :boolean, prefix: :string, live: :boolean]

  @default_opts [schema: true, context: true]

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.context must be invoked from within your *_web application root directory"
    end

    {context, schema} = build(args)
    binding = [context: context, schema: schema]
    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context)
    prompt_for_code_injection(context)

    context
    |> copy_new_files(paths, binding)
    |> print_shell_instructions()
  end

  defp prompt_for_conflicts(context) do
    context
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  @doc false
  def build(args, help \\ __MODULE__) do
    {opts, parsed, _} = parse_opts(args)
    [context_name, schema_name, plural | schema_args] = validate_args!(parsed, help)
    schema_module = inspect(Module.concat(context_name, schema_name))
    schema = Gen.Schema.build([schema_module, plural | schema_args], opts, help)
    context = Context.new(context_name, schema, opts)
    {context, schema}
  end

  defp parse_opts(args) do
    {opts, parsed, invalid} = OptionParser.parse(args, switches: @switches)
    merged_opts =
      @default_opts
      |> Keyword.merge(opts)
      |> put_context_app(opts[:context_app])

    {merged_opts, parsed, invalid}
  end
  defp put_context_app(opts, nil), do: opts
  defp put_context_app(opts, string) do
    Keyword.put(opts, :context_app, String.to_atom(string))
  end

  @doc false
  def files_to_be_generated(%Context{schema: schema}) do
    if schema.generate? do
      Gen.Schema.files_to_be_generated(schema)
    else
      []
    end
  end

  @doc false
  def copy_new_files(%Context{schema: schema} = context, paths, binding) do
    if schema.generate?, do: Gen.Schema.copy_new_files(schema, paths, binding)
    inject_schema_access(context, paths, binding)
    inject_tests(context, paths, binding)
    inject_test_fixture(context, paths, binding)

    context
  end

  @doc false
  def ensure_context_file_exists(%Context{file: file} = context, paths, binding) do
    unless Context.pre_existing?(context) do
      Mix.Generator.create_file(file, Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.context/context.ex", binding))
    end
  end

  defp inject_schema_access(%Context{file: file} = context, paths, binding) do
    ensure_context_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.context/#{schema_access_template(context)}", binding)
    |> inject_eex_before_final_end(file, binding)
  end

  defp write_file(content, file) do
    File.write!(file, content)
  end

  @doc false
  def ensure_test_file_exists(%Context{test_file: test_file} = context, paths, binding) do
    unless Context.pre_existing_tests?(context) do
      Mix.Generator.create_file(test_file, Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.context/context_test.exs", binding))
    end
  end

  defp inject_tests(%Context{test_file: test_file} = context, paths, binding) do
    ensure_test_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.context/test_cases.exs", binding)
    |> inject_eex_before_final_end(test_file, binding)
  end

  @doc false
  def ensure_test_fixtures_file_exists(%Context{test_fixtures_file: test_fixtures_file} = context, paths, binding) do
    unless Context.pre_existing_test_fixtures?(context) do
      Mix.Generator.create_file(test_fixtures_file, Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.context/fixtures_module.ex", binding))
    end
  end

  defp inject_test_fixture(%Context{test_fixtures_file: test_fixtures_file} = context, paths, binding) do
    ensure_test_fixtures_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.context/fixtures.ex", binding)
    |> Mix.Phoenix.prepend_newline()
    |> inject_eex_before_final_end(test_fixtures_file, binding)

    maybe_print_unimplemented_fixture_functions(context)
  end

  defp maybe_print_unimplemented_fixture_functions(%Context{} = context) do
    fixture_functions_needing_implementations =
      Enum.flat_map(
        context.schema.fixture_unique_functions,
        fn
          {_field, {_function_name, function_def, true}} -> [function_def]
          {_field, {_function_name, _function_def, false}} -> []
        end
      )

    if Enum.any?(fixture_functions_needing_implementations) do
      Mix.shell.info(
        """

        Some of the generated database columns are unique. Please provide
        unique implementations for the following fixture function(s) in
        #{context.test_fixtures_file}:

        #{
          fixture_functions_needing_implementations
          |> Enum.map_join(&indent(&1, 2))
          |> String.trim_trailing()
        }
        """
      )
    end
  end

  defp indent(string, spaces) do
    indent_string = String.duplicate(" ", spaces)

    string
    |> String.split("\n")
    |> Enum.map_join(fn line ->
        if String.trim(line) == "" do
          "\n"
        else
          indent_string <> line <> "\n"
        end
    end)
  end

  defp inject_eex_before_final_end(content_to_inject, file_path, binding) do
    file = File.read!(file_path)

    if String.contains?(file, content_to_inject) do
      :ok
    else
      Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path)])

      file
      |> String.trim_trailing()
      |> String.trim_trailing("end")
      |> EEx.eval_string(binding)
      |> Kernel.<>(content_to_inject)
      |> Kernel.<>("end\n")
      |> write_file(file_path)
    end
  end

  @doc false
  def print_shell_instructions(%Context{schema: schema}) do
    if schema.generate? do
      Gen.Schema.print_shell_instructions(schema)
    else
      :ok
    end
  end

  defp schema_access_template(%Context{schema: schema}) do
    if schema.generate? do
      "schema_access.ex"
    else
      "access_no_schema.ex"
    end
  end

  defp validate_args!([context, schema, _plural | _] = args, help) do
    cond do
      not Context.valid?(context) ->
        help.raise_with_help "Expected the context, #{inspect context}, to be a valid module name"
      not Schema.valid?(schema) ->
        help.raise_with_help "Expected the schema, #{inspect schema}, to be a valid module name"
      context == schema ->
        help.raise_with_help "The context and schema should have different names"
      context == Mix.Phoenix.base() ->
        help.raise_with_help "Cannot generate context #{context} because it has the same name as the application"
      schema == Mix.Phoenix.base() ->
        help.raise_with_help "Cannot generate schema #{schema} because it has the same name as the application"
      true ->
        args
    end
  end

  defp validate_args!(_, help) do
    help.raise_with_help "Invalid arguments"
  end

  @doc false
  def raise_with_help(msg) do
    Mix.raise """
    #{msg}

    mix phx.gen.html, phx.gen.json, phx.gen.live, and phx.gen.context
    expect a context module name, followed by singular and plural names
    of the generated resource, ending with any number of attributes.
    For example:

        mix phx.gen.html Accounts User users name:string
        mix phx.gen.json Accounts User users name:string
        mix phx.gen.live Accounts User users name:string
        mix phx.gen.context Accounts User users name:string

    The context serves as the API boundary for the given resource.
    Multiple resources may belong to a context and a resource may be
    split over distinct contexts (such as Accounts.User and Payments.User).
    """
  end

  @doc false
  def prompt_for_code_injection(%Context{generate?: false}), do: :ok
  def prompt_for_code_injection(%Context{} = context) do
    if Context.pre_existing?(context) && !merge_with_existing_context?(context) do
      System.halt()
    end
  end

  defp merge_with_existing_context?(%Context{} = context) do
    Keyword.get_lazy(context.opts, :merge_with_existing_context, fn ->
      function_count = Context.function_count(context)
      file_count = Context.file_count(context)

      Mix.shell().info("""
      You are generating into an existing context.

      The #{inspect(context.module)} context currently has #{singularize(function_count, "functions")} and \
      #{singularize(file_count, "files")} in its directory.

        * It's OK to have multiple resources in the same context as \
      long as they are closely related. But if a context grows too \
      large, consider breaking it apart

        * If they are not closely related, another context probably works better

      The fact two entities are related in the database does not mean they belong \
      to the same context.

      If you are not sure, prefer creating a new context over adding to the existing one.
      """)

      Mix.shell().yes?("Would you like to proceed?")
    end)
  end

  defp singularize(1, plural), do: "1 " <> String.trim_trailing(plural, "s")
  defp singularize(amount, plural), do: "#{amount} #{plural}"
end
