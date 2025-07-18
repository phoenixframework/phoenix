defmodule Mix.Tasks.Phx.Gen.Json do
  @shortdoc "Generates context and controller for a JSON resource"

  @moduledoc """
  Generates controller, JSON view, and context for a JSON resource.

  The format is:

  ```console
  $ mix phx.gen.json [<context>] <schema> <table> <attr:type> [<attr:type>...]
  ```

  For example:

  ```console
  $ mix phx.gen.json User users name:string age:integer
  ```

  Will generate a `User` schema for the `users` table within the `Users` context,
  with the attributes `name` (as a string) and `age` (as an integer).

  You can also explicitly pass the context name as argument, whenever the context
  is well defined:

  ```console
  $ mix phx.gen.json Accounts User users name:string age:integer
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

    * a context module in `lib/app/accounts.ex` for the accounts API
    * a schema in `lib/app/accounts/user.ex`, with an `users` table
    * a controller in `lib/app_web/controllers/user_controller.ex`
    * a JSON view collocated with the controller in `lib/app_web/controllers/user_json.ex`

  A migration file for the repository and test files for the context and
  controller features will also be generated.

  ## API Prefix

  By default, the prefix "/api" will be generated for API route paths.
  This can be customized via the `:api_prefix` generators configuration:

      config :your_app, :generators,
        api_prefix: "/api/v1"

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
  $ mix phx.gen.json Accounts User users --web Accounts
  ```

  Which would generate a `lib/app_web/controllers/accounts/user_controller.ex` and
  `lib/app_web/controllers/accounts/user_json.ex`.

  ## Customizing the context, schema, tables and migrations

  In some cases, you may wish to bootstrap JSON views, controllers,
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

  alias Mix.Phoenix.{Context, Scope}
  alias Mix.Tasks.Phx.Gen

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.json must be invoked from within your *_web application root directory"
      )
    end

    {context, schema} = Gen.Context.build(args, name_optional: true)

    if schema.attrs == [] do
      Mix.raise("""
      No attributes provided. The phx.gen.json generator requires at least one attribute. For example:

        mix phx.gen.json Accounts User users name:string

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
      scope: schema.scope,
      core_components?: Code.ensure_loaded?(Module.concat(context.web_module, "CoreComponents")),
      gettext?: Code.ensure_loaded?(Module.concat(context.web_module, "Gettext")),
      primary_key: schema.opts[:primary_key] || :id,
      conn_scope: conn_scope,
      context_scope_prefix: context_scope_prefix,
      scope_conn_route_prefix: Scope.route_prefix(conn_scope, schema),
      scope_param_route_prefix: Scope.route_prefix("scope", schema),
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
    web = Mix.Phoenix.web_path(context_app)
    test_prefix = Mix.Phoenix.web_test_path(context_app)
    web_path = to_string(schema.web_path)
    controller_pre = Path.join([web, "controllers", web_path])
    test_pre = Path.join([test_prefix, "controllers", web_path])

    [
      {:eex, "controller.ex", Path.join([controller_pre, "#{singular}_controller.ex"])},
      {:eex, "json.ex", Path.join([controller_pre, "#{singular}_json.ex"])},
      {:new_eex, "changeset_json.ex", Path.join([web, "controllers/changeset_json.ex"])},
      {:eex, "controller_test.exs", Path.join([test_pre, "#{singular}_controller_test.exs"])},
      {:new_eex, "fallback_controller.ex", Path.join([web, "controllers/fallback_controller.ex"])}
    ]
  end

  @doc false
  def copy_new_files(%Context{} = context, paths, binding) do
    files = files_to_be_generated(context)
    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.json", binding, files)
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

      Add the resource to your #{schema.web_namespace} :api scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

          scope "/#{schema.web_path}", #{inspect(Module.concat(context.web_module, schema.web_namespace))} do
            pipe_through :api
            ...
            resources "#{resource_path}", #{inspect(schema.alias)}Controller#{if schema.opts[:primary_key], do: ~s[, param: "#{schema.opts[:primary_key]}"]}
          end
      """)
    else
      Mix.shell().info("""

      Add the resource to the "#{Application.get_env(ctx_app, :generators)[:api_prefix] || "/api"}" scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

          resources "#{resource_path}", #{inspect(schema.alias)}Controller, except: [:new, :edit]#{if schema.opts[:primary_key], do: ~s[, param: "#{schema.opts[:primary_key]}"]}
      """)
    end

    if schema.scope do
      Mix.shell().info(
        "Ensure the routes are defined in a block that sets the `#{inspect(context.scope.assign_key)}` assign."
      )
    end

    if context.generate?, do: Gen.Context.print_shell_instructions(context)
  end
end
