defmodule Mix.Tasks.Phx.Gen.Html do
  @shortdoc "Generates context and controller for an HTML resource"

  @moduledoc """
  Generates controller with view, templates, schema and context for an HTML resource.

  The format is:

  ```console
  $ mix phx.gen.html [<context>] <schema> <table> <attr:type> [<attr:type>...]
  ```

  For example:

  ```console
  $ mix phx.gen.html User users name:string age:integer
  ```

  Will generate a `User` schema for the `users` table within the `Users` context,
  with the attributes `name` (as a string) and `age` (as an integer).

  You can also explicitly pass the context name as argument, whenever the context
  is well defined:

    ```console
  $ mix phx.gen.html Accounts User users name:string age:integer
  ```

  The first argument is the context module (`Accounts`) followed by
  the schema module (`User`), table name (`users`), and attributes.

  The context is an Elixir module that serves as an API boundary for
  the given resource. A context often holds many related resources.
  Therefore, if the context already exists, it will be augmented with
  functions for the given resource.

  The schema is responsible for mapping the database fields into an
  Elixir struct. It is followed by a list of attributes with their
  respective names and types. See `mix phx.gen.schema` for more
  information on attributes.

  Overall, this generator will add the following files to `lib/`:

    * a controller in `lib/my_app_web/controllers/user_controller.ex`
    * default CRUD HTML templates in `lib/my_app_web/controllers/user_html`
    * an HTML view collocated with the controller in `lib/my_app_web/controllers/user_html.ex`
    * a schema in `lib/my_app/accounts/user.ex`, with an `users` table
    * a context module in `lib/my_app/accounts.ex` for the accounts API

  Additionally, this generator creates the following files:

    * a migration for the schema in `priv/repo/migrations`
    * a controller test module in `test/my_app/controllers/user_controller_test.exs`
    * a context test module in `test/my_app/accounts_test.exs`
    * a context test helper module in `test/support/fixtures/accounts_fixtures.ex`

  If the context already exists, this generator injects functions for the given resource into
  the context, context test, and context test helper modules.

  ## Scopes

  If your application configures its own default [scope](scopes.md), then this generator
  will automatically make sure all of your context operations are correctly scoped.
  You can pass the `--no-scope` flag to disable the scoping.

  ## Umbrella app configuration

  By default, Phoenix injects both web and domain specific functionality into the same
  application. When using umbrella applications, those concerns are typically broken
  into two separate apps, your context application - let's call it `my_app` - and its web
  layer, which Phoenix assumes to be `my_app_web`.

  You can teach Phoenix to use this style via the `:context_app` configuration option
  in your `my_app_umbrella/config/config.exs`:

      config :my_app_web,
        ecto_repos: [Stuff.Repo],
        generators: [context_app: :my_app]

  Alternatively, the `--context-app` option may be supplied to the generator:

  ```console
  $ mix phx.gen.html Accounts User users --context-app my_app
  ```

  ## Web namespace

  By default, the controller and HTML views are not namespaced but you can add
  a namespace by passing the `--web` flag with a module name, for example:

  ```console
  $ mix phx.gen.html Accounts User users --web Accounts
  ```

  Which would generate a `lib/app_web/controllers/accounts/user_controller.ex` and
  `lib/app_web/controllers/accounts/user_html.ex`.

  ## Customizing the context, schema, tables and migrations

  In some cases, you may wish to bootstrap HTML templates, controllers,
  and controller tests, but leave internal implementation of the context
  or schema to yourself. You can use the `--no-context` and `--no-schema`
  flags for file generation control. Note `--no-context` implies `--no-schema`:

  ```console
  $ mix phx.gen.live Accounts User users --no-context name:string
  ```

  In the cases above, tests are still generated, but they will all fail.

  You can also change the table name or configure the migrations to
  use binary ids for primary keys, see `mix phx.gen.schema` for more
  information.
  """
  use Mix.Task

  alias Mix.Phoenix.{Context, Schema, Scope}
  alias Mix.Tasks.Phx.Gen

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.html must be invoked from within your *_web application root directory"
      )
    end

    Mix.Phoenix.ensure_live_view_compat!(__MODULE__)

    {context, schema} = Gen.Context.build(args, name_optional: true)

    if schema.attrs == [] do
      Mix.raise("""
      No attributes provided. The phx.gen.html generator requires at least one attribute. For example:

        mix phx.gen.html Accounts User users name:string

      """)
    end

    Gen.Context.prompt_for_code_injection(context)

    {conn_scope, context_scope_prefix} =
      if schema.scope do
        base = "conn.assigns.#{schema.scope.assign_key}"
        {base, "#{base}, "}
      else
        {"", ""}
      end

    binding = [
      context: context,
      schema: schema,
      primary_key: schema.opts[:primary_key] || :id,
      scope: schema.scope,
      inputs: inputs(schema),
      conn_scope: conn_scope,
      context_scope_prefix: context_scope_prefix,
      scope_conn_route_prefix: Scope.route_prefix(conn_scope, schema),
      scope_param_route_prefix: Scope.route_prefix("scope", schema),
      scope_assign_route_prefix: scope_assign_route_prefix(schema),
      test_context_scope:
        if(schema.scope && schema.scope.route_prefix, do: ", scope: scope", else: "")
    ]

    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context)

    context
    |> copy_new_files(paths, binding)
    |> print_shell_instructions()
  end

  defp prompt_for_conflicts(context) do
    context
    |> files_to_be_generated()
    |> Kernel.++(context_files(context))
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  defp context_files(%Context{generate?: true} = context) do
    Gen.Context.files_to_be_generated(context)
  end

  defp context_files(%Context{generate?: false}) do
    []
  end

  @doc false
  def files_to_be_generated(%Context{schema: schema, context_app: context_app}) do
    singular = schema.singular
    web_prefix = Mix.Phoenix.web_path(context_app)
    test_prefix = Mix.Phoenix.web_test_path(context_app)
    web_path = to_string(schema.web_path)
    controller_pre = Path.join([web_prefix, "controllers", web_path])
    test_pre = Path.join([test_prefix, "controllers", web_path])

    [
      {:eex, "controller.ex", Path.join([controller_pre, "#{singular}_controller.ex"])},
      {:eex, "edit.html.heex", Path.join([controller_pre, "#{singular}_html", "edit.html.heex"])},
      {:eex, "index.html.heex",
       Path.join([controller_pre, "#{singular}_html", "index.html.heex"])},
      {:eex, "new.html.heex", Path.join([controller_pre, "#{singular}_html", "new.html.heex"])},
      {:eex, "show.html.heex", Path.join([controller_pre, "#{singular}_html", "show.html.heex"])},
      {:eex, "resource_form.html.heex",
       Path.join([controller_pre, "#{singular}_html", "#{singular}_form.html.heex"])},
      {:eex, "html.ex", Path.join([controller_pre, "#{singular}_html.ex"])},
      {:eex, "controller_test.exs", Path.join([test_pre, "#{singular}_controller_test.exs"])}
    ]
  end

  @doc false
  def copy_new_files(%Context{} = context, paths, binding) do
    files = files_to_be_generated(context)
    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.html", binding, files)
    if context.generate?, do: Gen.Context.copy_new_files(context, paths, binding)
    context
  end

  @doc false
  def print_shell_instructions(%Context{schema: schema, context_app: ctx_app} = context) do
    resource_path =
      if schema.scope && schema.scope.route_prefix do
        "#{schema.scope.route_prefix}/#{schema.plural}"
      else
        "/#{schema.plural}"
      end

    if schema.web_namespace do
      Mix.shell().info("""

      Add the resource to your #{schema.web_namespace} :browser scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

          scope "/#{schema.web_path}", #{inspect(Module.concat(context.web_module, schema.web_namespace))} do
            pipe_through :browser
            ...
            resources "#{resource_path}", #{inspect(schema.alias)}Controller#{if schema.opts[:primary_key], do: ~s[, param: "#{schema.opts[:primary_key]}"]}
          end
      """)
    else
      Mix.shell().info("""

      Add the resource to your browser scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

          resources "#{resource_path}", #{inspect(schema.alias)}Controller#{if schema.opts[:primary_key], do: ~s[, param: "#{schema.opts[:primary_key]}"]}
      """)
    end

    if schema.scope do
      Mix.shell().info(
        "Ensure the routes are defined in a block that sets the `#{inspect(context.scope.assign_key)}` assign."
      )
    end

    if context.generate?, do: Gen.Context.print_shell_instructions(context)
  end

  @doc false
  def inputs(%Schema{} = schema) do
    schema.attrs
    |> Enum.reject(fn {_key, type} -> type == :map end)
    |> Enum.map(fn
      {key, :integer} ->
        ~s(<.input field={f[#{inspect(key)}]} type="number" label="#{label(key)}" />)

      {key, :float} ->
        ~s(<.input field={f[#{inspect(key)}]} type="number" label="#{label(key)}" step="any" />)

      {key, :decimal} ->
        ~s(<.input field={f[#{inspect(key)}]} type="number" label="#{label(key)}" step="any" />)

      {key, :boolean} ->
        ~s(<.input field={f[#{inspect(key)}]} type="checkbox" label="#{label(key)}" />)

      {key, :text} ->
        ~s(<.input field={f[#{inspect(key)}]} type="textarea" label="#{label(key)}" />)

      {key, :date} ->
        ~s(<.input field={f[#{inspect(key)}]} type="date" label="#{label(key)}" />)

      {key, :time} ->
        ~s(<.input field={f[#{inspect(key)}]} type="time" label="#{label(key)}" />)

      {key, :utc_datetime} ->
        ~s(<.input field={f[#{inspect(key)}]} type="datetime-local" label="#{label(key)}" />)

      {key, :naive_datetime} ->
        ~s(<.input field={f[#{inspect(key)}]} type="datetime-local" label="#{label(key)}" />)

      {key, {:array, _} = type} ->
        ~s"""
        <.input
          field={f[#{inspect(key)}]}
          type="select"
          multiple
          label="#{label(key)}"
          options={#{inspect(default_options(type))}}
        />
        """

      {key, {:enum, _}} ->
        ~s"""
        <.input
          field={f[#{inspect(key)}]}
          type="select"
          label="#{label(key)}"
          prompt="Choose a value"
          options={Ecto.Enum.values(#{inspect(schema.module)}, #{inspect(key)})}
        />
        """

      {key, _} ->
        ~s(<.input field={f[#{inspect(key)}]} type="text" label="#{label(key)}" />)
    end)
  end

  defp default_options({:array, :string}),
    do: Enum.map([1, 2], &{"Option #{&1}", "option#{&1}"})

  defp default_options({:array, :integer}),
    do: Enum.map([1, 2], &{"#{&1}", &1})

  defp default_options({:array, _}), do: []

  defp label(key), do: Phoenix.Naming.humanize(to_string(key))

  defp scope_assign_route_prefix(
         %{scope: %{route_prefix: route_prefix, assign_key: assign_key}} = schema
       )
       when not is_nil(route_prefix) do
    Scope.route_prefix("@#{assign_key}", schema)
  end

  defp scope_assign_route_prefix(_), do: ""

  @doc false
  def indent_inputs(inputs, column_padding) do
    columns = String.duplicate(" ", column_padding)

    inputs
    |> Enum.map(fn input ->
      lines = input |> String.split("\n") |> Enum.reject(&(&1 == ""))

      case lines do
        [] ->
          []

        [line] ->
          [columns, line]

        [first_line | rest] ->
          rest = Enum.map_join(rest, "\n", &(columns <> &1))
          [columns, first_line, "\n", rest]
      end
    end)
    |> Enum.intersperse("\n")
  end
end
