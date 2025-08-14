defmodule Mix.Tasks.Phx.Gen.Live do
  @shortdoc "Generates LiveView, templates, and context for a resource"

  @moduledoc """
  Generates LiveView, templates, and context for a resource.

  The format is:

  ```console
  $ mix phx.gen.live [<context>] <schema> <table> <attr:type> [<attr:type>...]
  ```

  For example:

  ```console
  $ mix phx.gen.live User users name:string age:integer
  ```

  Will generate a `User` schema for the `users` table within the `Users` context,
  with the attributes `name` (as a string) and `age` (as an integer).

  You can also explicitly pass the context name as argument, whenever the context
  is well defined:

  ```console
  $ mix phx.gen.live Accounts User users name:string age:integer
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
    * a schema in `lib/app/accounts/user.ex`, with a `users` table
    * a LiveView in `lib/app_web/live/user_live/show.ex`
    * a LiveView in `lib/app_web/live/user_live/index.ex`
    * a LiveView in `lib/app_web/live/user_live/form.ex`
    * a components module in `lib/app_web/components/core_components.ex`
      if none exists

  After file generation is complete, there will be output regarding required
  updates to the `lib/app_web/router.ex` file.

      Add the live routes to your browser scope in lib/app_web/router.ex:

        live "/users", UserLive.Index, :index
        live "/users/new", UserLive.Form, :new
        live "/users/:id", UserLive.Show, :show
        live "/users/:id/edit", UserLive.Form, :edit

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

  By default, the LiveView modules are defined within a folder named
  after the schema, such as `lib/app_web/live/user_live`. You can add
  additional namespaces by passing the `--web` flag with a module name,
  for example:

  ```console
  $ mix phx.gen.live Accounts User users --web Accounts name:string
  ```

  Which would generate the LiveViews in `lib/app_web/live/accounts/user_live/`,
  namespaced `AppWeb.Accounts.UserLive` instead of `AppWeb.UserLive`.

  ## Customizing the context, schema, tables and migrations

  In some cases, you may wish to bootstrap HTML templates, LiveViews,
  and tests, but leave internal implementation of the context or schema
  to yourself. You can use the `--no-context` and `--no-schema` flags
  flags for file generation control. Note `--no-context` implies `--no-schema`:

  ```console
  $ mix phx.gen.live Accounts User users --no-context name:string
  ```

  In the cases above, tests are still generated, but they will all fail.

  You can also change the table name or configure the migrations to
  use binary ids for primary keys, see `mix help phx.gen.schema` for more
  information.
  """
  use Mix.Task

  alias Mix.Phoenix.{Context, Schema, Scope}
  alias Mix.Tasks.Phx.Gen

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.live must be invoked from within your *_web application root directory"
      )
    end

    Mix.Phoenix.ensure_live_view_compat!(__MODULE__)

    {context, schema} = Gen.Context.build(args, name_optional: true)
    validate_context!(context)

    if schema.attrs == [] do
      Mix.raise("""
      No attributes provided. The phx.gen.live generator requires at least one attribute. For example:

        mix phx.gen.live Accounts User users name:string

      """)
    end

    Gen.Context.prompt_for_code_injection(context)

    {socket_scope, context_scope_prefix, assign_scope, assign_scope_prefix} =
      if schema.scope do
        base_socket = "socket.assigns.#{schema.scope.assign_key}"
        base_assign = "@#{schema.scope.assign_key}"
        {base_socket, "#{base_socket}, ", base_assign, "#{base_assign}, "}
      else
        {"", "", "", ""}
      end

    binding = [
      context: context,
      schema: schema,
      primary_key: schema.opts[:primary_key] || :id,
      scope: schema.scope,
      inputs: inputs(schema),
      socket_scope: socket_scope,
      context_scope_prefix: context_scope_prefix,
      assign_scope: assign_scope,
      assign_scope_prefix: assign_scope_prefix,
      scope_param_route_prefix: Scope.route_prefix("scope", schema),
      scope_param: scope_param(schema),
      scope_param_prefix: scope_param_prefix(schema),
      scope_socket_route_prefix: Scope.route_prefix(socket_scope, schema),
      scope_assign_route_prefix: scope_assign_route_prefix(schema),
      test_context_scope:
        if(schema.scope && schema.scope.route_prefix, do: ", scope: scope", else: "")
    ]

    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context)

    context
    |> copy_new_files(binding, paths)
    |> maybe_inject_imports()
    |> print_shell_instructions()
  end

  defp validate_context!(context) do
    cond do
      context.schema.singular == "form" ->
        Gen.Context.raise_with_help(
          "cannot use form as the schema name because it conflicts with the LiveView assigns!"
        )

      true ->
        :ok
    end
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

  defp files_to_be_generated(%Context{schema: schema, context_app: context_app}) do
    web_prefix = Mix.Phoenix.web_path(context_app)
    test_prefix = Mix.Phoenix.web_test_path(context_app)
    web_path = to_string(schema.web_path)
    live_subdir = "#{schema.singular}_live"
    web_live = Path.join([web_prefix, "live", web_path, live_subdir])
    test_live = Path.join([test_prefix, "live", web_path])

    [
      {:eex, "show.ex", Path.join(web_live, "show.ex")},
      {:eex, "index.ex", Path.join(web_live, "index.ex")},
      {:eex, "form.ex", Path.join(web_live, "form.ex")},
      {:eex, "live_test.exs", Path.join(test_live, "#{schema.singular}_live_test.exs")},
      {:new_eex, "core_components.ex",
       Path.join([web_prefix, "components", "core_components.ex"])}
    ]
  end

  defp copy_new_files(%Context{} = context, binding, paths) do
    files = files_to_be_generated(context)

    binding =
      Keyword.merge(binding,
        assigns: %{
          web_namespace: inspect(context.web_module),
          gettext: true,
          live: true,
          # the core components are also generated in phx.new, so we check for
          # esbuild (@javascript) - here we just assume that it's there
          javascript: true
        }
      )

    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.live", binding, files)
    if context.generate?, do: Gen.Context.copy_new_files(context, paths, binding)

    context
  end

  defp maybe_inject_imports(%Context{context_app: ctx_app} = context) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    [lib_prefix, web_dir] = Path.split(web_prefix)
    file_path = Path.join(lib_prefix, "#{web_dir}.ex")
    file = File.read!(file_path)
    inject = "import #{inspect(context.web_module)}.CoreComponents"

    if String.contains?(file, inject) do
      :ok
    else
      do_inject_imports(context, file, file_path, inject)
    end

    context
  end

  defp do_inject_imports(context, file, file_path, inject) do
    Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path)])

    new_file =
      String.replace(
        file,
        "use Phoenix.Component",
        "use Phoenix.Component\n      #{inject}"
      )

    if file != new_file do
      File.write!(file_path, new_file)
    else
      Mix.shell().info("""

      Could not find use Phoenix.Component in #{file_path}.

      This typically happens because your application was not generated
      with the --live flag:

          mix phx.new my_app --live

      Please make sure LiveView is installed and that #{inspect(context.web_module)}
      defines both `live_view/0` and `live_component/0` functions,
      and that both functions import #{inspect(context.web_module)}.CoreComponents.
      """)
    end
  end

  @doc false
  def print_shell_instructions(%Context{schema: schema, context_app: ctx_app} = context) do
    prefix = Module.concat(context.web_module, schema.web_namespace)
    web_path = Mix.Phoenix.web_path(ctx_app)

    if schema.web_namespace do
      Mix.shell().info("""

      Add the live routes to your #{schema.web_namespace} :browser scope in #{web_path}/router.ex:

          scope "/#{schema.web_path}", #{inspect(prefix)} do
            pipe_through :browser
            ...

      #{for line <- live_route_instructions(schema), do: "      #{line}"}
          end
      """)
    else
      Mix.shell().info("""

      Add the live routes to your browser scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

      #{for line <- live_route_instructions(schema), do: "    #{line}"}
      """)
    end

    if schema.scope do
      Mix.shell().info(
        "Ensure the routes are defined in a block that sets the `#{inspect(context.scope.assign_key)}` assign."
      )
    end

    if context.generate?, do: Gen.Context.print_shell_instructions(context)
    maybe_print_upgrade_info()
  end

  defp maybe_print_upgrade_info do
    unless Code.ensure_loaded?(Phoenix.LiveView.JS) do
      Mix.shell().info("""

      You must update :phoenix_live_view to v0.18 or later and
      :phoenix_live_dashboard to v0.7 or later to use the features
      in this generator.
      """)
    end
  end

  defp live_route_instructions(schema) do
    route_base =
      if schema.scope && schema.scope.route_prefix do
        scope_prefix = schema.scope.route_prefix
        "#{scope_prefix}/#{schema.plural}"
      else
        "/#{schema.plural}"
      end

    [
      ~s|live "#{route_base}", #{inspect(schema.alias)}Live.Index, :index\n|,
      ~s|live "#{route_base}/new", #{inspect(schema.alias)}Live.Form, :new\n|,
      ~s|live "#{route_base}/:#{schema.opts[:primary_key] || :id}", #{inspect(schema.alias)}Live.Show, :show\n|,
      ~s|live "#{route_base}/:#{schema.opts[:primary_key] || :id}/edit", #{inspect(schema.alias)}Live.Form, :edit|
    ]
  end

  @doc false
  def inputs(%Schema{} = schema) do
    schema.attrs
    |> Enum.reject(fn {_key, type} -> type == :map end)
    |> Enum.map(fn
      {_, {:references, _}} ->
        nil

      {key, :integer} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="number" label="#{label(key)}" />)

      {key, :float} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="number" label="#{label(key)}" step="any" />)

      {key, :decimal} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="number" label="#{label(key)}" step="any" />)

      {key, :boolean} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="checkbox" label="#{label(key)}" />)

      {key, :text} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="textarea" label="#{label(key)}" />)

      {key, :date} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="date" label="#{label(key)}" />)

      {key, :time} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="time" label="#{label(key)}" />)

      {key, :utc_datetime} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="datetime-local" label="#{label(key)}" />)

      {key, :naive_datetime} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="datetime-local" label="#{label(key)}" />)

      {key, {:array, _} = type} ->
        ~s"""
        <.input
          field={@form[#{inspect(key)}]}
          type="select"
          multiple
          label="#{label(key)}"
          options={#{inspect(default_options(type))}}
        />
        """

      {key, {:enum, _}} ->
        ~s"""
        <.input
          field={@form[#{inspect(key)}]}
          type="select"
          label="#{label(key)}"
          prompt="Choose a value"
          options={Ecto.Enum.values(#{inspect(schema.module)}, #{inspect(key)})}
        />
        """

      {key, _} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="text" label="#{label(key)}" />)
    end)
  end

  defp default_options({:array, :string}),
    do: Enum.map([1, 2], &{"Option #{&1}", "option#{&1}"})

  defp default_options({:array, :integer}),
    do: Enum.map([1, 2], &{"#{&1}", &1})

  defp default_options({:array, _}), do: []

  defp label(key), do: Phoenix.Naming.humanize(to_string(key))

  defp scope_param(%{scope: nil}), do: ""

  defp scope_param(%{scope: %{route_prefix: route_prefix}}) when not is_nil(route_prefix),
    do: "scope"

  defp scope_param(_), do: "_scope"

  defp scope_param_prefix(schema) do
    param = scope_param(schema)
    if param != "", do: "#{param}, ", else: ""
  end

  defp scope_assign_route_prefix(
         %{scope: %{route_prefix: route_prefix, assign_key: assign_key}} = schema
       )
       when not is_nil(route_prefix) do
    Scope.route_prefix("@#{assign_key}", schema)
  end

  defp scope_assign_route_prefix(_), do: ""
end
