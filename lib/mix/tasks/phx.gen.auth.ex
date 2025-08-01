defmodule Mix.Tasks.Phx.Gen.Auth do
  @shortdoc "Generates authentication logic for a resource"

  @moduledoc """
  Generates authentication logic and related views for a resource.

  ```console
  $ mix phx.gen.auth Accounts User users
  ```

  The first argument is the context module followed by the schema module
  and its plural name (used as the schema table name). The example above
  will generate an `Accounts` context module with two schemas inside:
  `User` and `UserToken`. You may name the context and schema according
  to your preferences. For example:

  ```console
  $ mix phx.gen.auth Identity Client clients
  ```

  Will generate an `Identity` context with `Client` and `ClientToken` inside.
  Additional information and security considerations are detailed in the
  [`mix phx.gen.auth` guide](mix_phx_gen_auth.html).

  > #### A note on scopes {: .info}
  >
  > `mix phx.gen.auth` creates a scope named after the schema by default.
  > You can read more about scopes in the [Scopes guide](scopes.html).

  ## LiveView vs conventional Controllers & Views

  Authentication views can either be generated to use LiveView by passing
  the `--live` option, or they can use conventional Phoenix
  Controllers & Views by passing `--no-live`.

  If neither of these options are provided, a prompt will be displayed.

  Using the `--live` option is advised if you plan on using LiveView
  elsewhere in your application. The user experience when navigating between
  LiveViews can be tightly controlled, allowing you to let your users navigate
  to authentication views without necessarily triggering a new HTTP request
  each time (which would result in a full page load).

  ## Mixing magic link and password registration

  `mix phx.gen.auth` generates email based authentication, which assumes the user who
  owns the email address has control over the account. Therefore, it is extremely
  important to void all access tokens once the user confirms their account for the first
  time, and we do so by revoking all tokens upon confirmation.

  However, if you allow users to create an account with password, you must also
  require them to be logged in by the time of confirmation, otherwise you may be
  vulnerable to credential pre-stuffing, as the following attack is possible:

  1. An attacker registers a new account with the email address of their target, anticipating
     that the target creates an account at a later point in time.
  2. The attacker sets a password when registering.
  3. The target registers an account and sees that their email address is already in use.
  4. The target logs in by magic link, but does not change the existing password.
  5. The attacker maintains access using the password they previously set.

  This is why the default implementation raises whenever a user tries to log in for the first
  time by magic link and there is a password set. If you add registration with email and
  password, then you must require the user to be logged in to confirm their account.
  If they don't have a password (because it was set by the attacker), then they can set one
  via a "Forgot your password?"-like workflow.

  ## Password hashing

  The password hashing mechanism defaults to `bcrypt` for
  Unix systems and `pbkdf2` for Windows systems. Both
  systems use the [Comeonin interface](https://hexdocs.pm/comeonin/).

  The password hashing mechanism can be overridden with the
  `--hashing-lib` option. The following values are supported:

    * `bcrypt` - [bcrypt_elixir](https://hex.pm/packages/bcrypt_elixir)
    * `pbkdf2` - [pbkdf2_elixir](https://hex.pm/packages/pbkdf2_elixir)
    * `argon2` - [argon2_elixir](https://hex.pm/packages/argon2_elixir)

  We recommend developers to consider using `argon2`, which
  is the most robust of all 3. The downside is that `argon2`
  is quite CPU and memory intensive, and you will need more
  powerful instances to run your applications on.

  For more information about choosing these libraries, see the
  [Comeonin project](https://github.com/riverrun/comeonin).

  ## Multiple invocations

  You can invoke this generator multiple times. This is typically useful
  if you have distinct resources that go through distinct authentication
  workflows:

      $ mix phx.gen.auth Store User users
      $ mix phx.gen.auth Backoffice Admin admins

  Note that when invoking `phx.gen.auth` multiple times, it will also generate
  multiple [scopes](guides/authn_authz/scopes.md). Typically, only one scope is needed,
  thus you will probably want to customize the generated code afterwards. Also, it
  is expected that the generated code is not fully free of conflicts. One example is the
  browser pipeline, which will try to assign both scopes as `:current_scope` by default.
  You can customize the generated assign key with the `--assign-key` option.

  ## Binary ids

  The `--binary-id` option causes the generated migration to use
  `binary_id` for its primary key and foreign keys.

  ## Default options

  This generator uses default options provided in the `:generators`
  configuration of your application. These are the defaults:

      config :your_app, :generators,
        binary_id: false,
        sample_binary_id: "11111111-1111-1111-1111-111111111111"

  You can override those options per invocation by providing corresponding
  switches, e.g. `--no-binary-id` to use normal ids despite the default
  configuration.

  ## Custom table names

  By default, the table name for the migration and schema will be
  the plural name provided for the resource. To customize this value,
  a `--table` option may be provided. For example:

      $ mix phx.gen.auth Accounts User users --table accounts_users

  This will cause the generated tables to be named `"accounts_users"` and `"accounts_users_tokens"`.

  ## Custom scope name

  By default, the scope name is the same as the schema name. You can customize the scope name by passing the `--scope` option. For example:

  ```console
  $ mix phx.gen.auth Accounts User users --scope app_user
  ```

  This will generate a scope named `app_user` instead of `user`. You can read more about scopes in the [Scopes guide](scopes.html).

  Additionally, the scope's assign key can be customized by passing the `--assign-key` option. For example:

  ```console
  $ mix phx.gen.auth Accounts User users --assign-key current_user_scope
  ```

  This is useful when you want to run `mix phx.gen.auth` multiple times in the same project, but note that
  often it might make more sense to reuse the same scope with additional fields instead of separate scopes.
  """

  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen
  alias Mix.Tasks.Phx.Gen.Auth.{HashingLibrary, Injector, Migration}

  @switches [
    web: :string,
    binary_id: :boolean,
    hashing_lib: :string,
    table: :string,
    merge_with_existing_context: :boolean,
    prefix: :string,
    live: :boolean,
    compile: :boolean,
    scope: :string,
    assign_key: :string,
    agents_md: :boolean
  ]

  @doc false
  def run(args, test_opts \\ []) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix phx.gen.auth can only be run inside an application directory")
    end

    Mix.Phoenix.ensure_live_view_compat!(__MODULE__)

    {opts, parsed} = OptionParser.parse!(args, strict: @switches)
    validate_args!(parsed)
    hashing_library = build_hashing_library!(opts)

    context_args =
      OptionParser.to_argv(Keyword.drop(opts, [:scope, :assign_key, :agents_md]),
        switches: @switches
      ) ++
        parsed

    {context, schema} = Gen.Context.build(context_args ++ ["--no-scope"], help_module: __MODULE__)

    context = put_live_option(context)
    Gen.Context.prompt_for_code_injection(context)

    if "--no-compile" not in args do
      # Needed so we can get the ecto adapter and ensure other
      # libraries are loaded.
      Mix.Task.run("compile")
      validate_required_dependencies!()
    end

    ecto_adapter =
      Keyword.get_lazy(
        test_opts,
        :ecto_adapter,
        fn -> get_ecto_adapter!(schema) end
      )

    migration = Migration.build(ecto_adapter)

    binding = [
      context: context,
      schema: schema,
      migration: migration,
      hashing_library: hashing_library,
      web_app_name: web_app_name(context),
      web_namespace: context.web_module,
      endpoint_module: Module.concat([context.web_module, Endpoint]),
      auth_module:
        Module.concat([context.web_module, schema.web_namespace, "#{inspect(schema.alias)}Auth"]),
      router_scope: router_scope(context),
      web_path_prefix: web_path_prefix(schema),
      test_case_options: test_case_options(ecto_adapter),
      live?: Keyword.fetch!(context.opts, :live),
      datetime_module: datetime_module(schema),
      datetime_now: datetime_now(schema),
      scope_config:
        scope_config(context, opts[:scope], Keyword.get(opts, :assign_key, "current_scope")),
      agents_md: Keyword.get(opts, :agents_md, true)
    ]

    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(binding)

    context
    |> copy_new_files(binding, paths)
    |> inject_conn_case_helpers(paths, binding)
    |> inject_hashing_config(hashing_library)
    |> maybe_inject_scope_config(binding)
    |> maybe_inject_mix_dependency(hashing_library)
    |> inject_routes(paths, binding)
    |> maybe_inject_router_import(binding)
    |> maybe_inject_router_plug(binding)
    |> maybe_inject_app_layout_menu(binding)
    |> maybe_inject_agents_md(paths, binding)
    |> Gen.Notifier.maybe_print_mailer_installation_instructions()
    |> print_shell_instructions()
  end

  defp web_app_name(%Context{} = context) do
    context.web_module
    |> inspect()
    |> Phoenix.Naming.underscore()
  end

  defp validate_args!([_, _, _]), do: :ok

  defp validate_args!(_) do
    raise_with_help("Invalid arguments")
  end

  defp validate_required_dependencies! do
    unless Code.ensure_loaded?(Ecto.Adapters.SQL) do
      raise_with_help("mix phx.gen.auth requires ecto_sql", :phx_generator_args)
    end

    if generated_with_no_html?() do
      raise_with_help("mix phx.gen.auth requires phoenix_html", :phx_generator_args)
    end

    if generated_with_no_assets_or_esbuild?() do
      Mix.shell().yes?("""
      Warning: did not find phoenix_html in your app.js.

      phx.gen.auth expects the phoenix_html JavaScript to be available in your application for
      the generated logout link to work.
      This is not the case for applications generated with `--no-assets` or `--no-esbuild`.

      To make the logout link work, you'll need to manually add the phoenix_html JavaScript to your application.
      It is available at the "priv/static/phoenix_html" path of the phoenix_html application.

      Alternatively, you can refactor the logout link to submit a `<form>` with method "delete" instead.

      Continue?\
      """) || System.halt()
    end
  end

  defp generated_with_no_html? do
    Mix.Project.config()
    |> Keyword.get(:deps, [])
    |> Enum.any?(fn
      {:phoenix_html, _} -> true
      {:phoenix_html, _, _} -> true
      _ -> false
    end)
    |> Kernel.not()
  end

  defp generated_with_no_assets_or_esbuild? do
    not Code.ensure_loaded?(Phoenix.HTML) or
      case File.read("assets/js/app.js") do
        {:ok, content} -> content =~ "priv/static/phoenix_html.js"
        {:error, _} -> true
      end
  end

  defp build_hashing_library!(opts) do
    opts
    |> Keyword.get_lazy(:hashing_lib, &default_hashing_library_option/0)
    |> HashingLibrary.build()
    |> case do
      {:ok, hashing_library} ->
        hashing_library

      {:error, {:unknown_library, unknown_library}} ->
        raise_with_help(
          "Unknown value for --hashing-lib #{inspect(unknown_library)}",
          :hashing_lib
        )
    end
  end

  defp default_hashing_library_option do
    case :os.type() do
      {:unix, _} -> "bcrypt"
      {:win32, _} -> "pbkdf2"
    end
  end

  defp scope_config(context, requested_scope, assign_key) do
    existing_scopes = Mix.Phoenix.Scope.scopes_from_config(context.context_app)

    {_, default_scope} =
      Enum.find(existing_scopes, {nil, nil}, fn {_, scope} -> scope.default end)

    key = String.to_atom(requested_scope || find_scope_name(context, existing_scopes))

    {create_new?, scope, config_string} =
      if Map.has_key?(existing_scopes, key) do
        {false, existing_scopes[key], nil}
      else
        {true, new_scope(context, key, default_scope, assign_key),
         scope_config_string(context, key, default_scope, assign_key)}
      end

    %{
      scopes: existing_scopes,
      default_scope: default_scope,
      create_new?: create_new?,
      scope: scope,
      config_string: config_string
    }
  end

  defp find_scope_name(context, existing_scopes) do
    cond do
      # user
      is_new_scope?(existing_scopes, context.schema.singular) ->
        context.schema.singular

      # accounts_user
      is_new_scope?(existing_scopes, "#{context.basename}_#{context.schema.singular}") ->
        "#{context.basename}_#{context.schema.singular}"

      # my_app_accounts_user
      is_new_scope?(
        existing_scopes,
        "#{context.context_app}_#{context.basename}_#{context.schema.singular}"
      ) ->
        "#{context.context_app}_#{context.basename}_#{context.schema.singular}"

      true ->
        Mix.raise("""
        Could not generate a scope name for #{context.schema.singular}! These scopes already exist:

            * #{Enum.map(existing_scopes, fn {name, _scope} -> name end) |> Enum.join("\n    * ")}

        You can customize the scope name by passing the --scope option.
        """)
    end
  end

  defp is_new_scope?(existing_scopes, bin_key) do
    key = String.to_atom(bin_key)
    not Map.has_key?(existing_scopes, key)
  end

  defp new_scope(context, key, default_scope, assign_key) do
    Mix.Phoenix.Scope.new!(key, %{
      default: !default_scope,
      module: Module.concat([context.module, "Scope"]),
      assign_key: String.to_atom(assign_key),
      access_path: [
        String.to_atom(context.schema.singular),
        context.schema.opts[:primary_key] || :id
      ],
      schema_key:
        String.to_atom("#{context.schema.singular}_#{context.schema.opts[:primary_key] || :id}"),
      schema_type: if(context.schema.binary_id, do: :binary_id, else: :id),
      schema_table: context.schema.table,
      test_data_fixture: Module.concat([context.module, "Fixtures"]),
      test_setup_helper: :"register_and_log_in_#{context.schema.singular}"
    })
  end

  defp scope_config_string(context, key, default_scope, assign_key) do
    """
    config :#{context.context_app}, :scopes,
      #{key}: [
        default: #{if default_scope, do: false, else: true},
        module: #{inspect(context.module)}.Scope,
        assign_key: :#{assign_key},
        access_path: [:#{context.schema.singular}, :#{context.schema.opts[:primary_key] || :id}],
        schema_key: :#{context.schema.singular}_#{context.schema.opts[:primary_key] || :id},
        schema_type: :#{if(context.schema.binary_id, do: :binary_id, else: :id)},
        schema_table: :#{context.schema.table},
        test_data_fixture: #{inspect(context.module)}Fixtures,
        test_setup_helper: :register_and_log_in_#{context.schema.singular}
      ]\
    """
  end

  defp prompt_for_conflicts(binding) do
    prompt_for_scope_conflicts(binding)

    binding
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  defp prompt_for_scope_conflicts(binding) do
    schema = binding[:schema]
    %{scope: scope, default_scope: default_scope, create_new?: new?} = binding[:scope_config]

    cond do
      # this can only happen if --scope is used and the user explicitly asked for the scope name
      scope && not new? ->
        Mix.shell().yes?("""
        The scope #{scope.name} is already configured.

        phx.gen.auth expects the configured scope module #{inspect(scope.module)} to include
        a `for_#{schema.singular}/1` function that returns a `%#{inspect(schema.module)}{}` struct:

            def for_#{schema.singular}(nil), do: %__MODULE__{user: nil}

            def for_#{schema.singular}(%<%= inspect schema.alias %>{} = #{schema.singular}) do
              %__MODULE__{#{schema.singular}: #{schema.singular}}
            end

        Please ensure that your scope module includes such code.

        Do you want to proceed with the generation?\
        """) || System.halt()

      default_scope ->
        Mix.shell().yes?("""
        Your application configuration already contains a default scope: #{inspect(default_scope.name)}.

        phx.gen.auth will create a new #{scope.name} scope.

        Note that if you run `phx.gen.live` multiple times, the generated assign key for
        the generated scopes can conflict with each other. You can pass `--assign-key` to customize
        the assign key for the generated scope.

        Do you want to proceed with the generation?\
        """) || System.halt()

      true ->
        :ok
    end
  end

  defp files_to_be_generated(binding) do
    schema = binding[:schema]
    context = binding[:context]
    context_app = context.context_app
    scope_config = binding[:scope_config]

    singular = schema.singular
    web_pre = Mix.Phoenix.web_path(context_app)
    web_test_pre = Mix.Phoenix.web_test_path(context_app)
    migrations_pre = Mix.Phoenix.context_app_path(context_app, "priv/repo/migrations")
    web_path = to_string(schema.web_path)
    controller_pre = Path.join([web_pre, "controllers", web_path])

    default_files =
      [
        "migration.ex": [migrations_pre, "#{timestamp()}_create_#{schema.table}_auth_tables.exs"],
        "notifier.ex": [context.dir, "#{singular}_notifier.ex"],
        "schema.ex": [context.dir, "#{singular}.ex"],
        "schema_token.ex": [context.dir, "#{singular}_token.ex"],
        "auth.ex": [web_pre, web_path, "#{singular}_auth.ex"],
        "auth_test.exs": [web_test_pre, web_path, "#{singular}_auth_test.exs"],
        "session_controller.ex": [controller_pre, "#{singular}_session_controller.ex"],
        "session_controller_test.exs": [
          web_test_pre,
          "controllers",
          web_path,
          "#{singular}_session_controller_test.exs"
        ]
      ] ++
        if scope_config.create_new? do
          ["scope.ex": [context.dir, "scope.ex"]]
        else
          []
        end

    case Keyword.fetch(context.opts, :live) do
      {:ok, true} ->
        live_files = [
          "registration_live.ex": [
            web_pre,
            "live",
            web_path,
            "#{singular}_live",
            "registration.ex"
          ],
          "registration_live_test.exs": [
            web_test_pre,
            "live",
            web_path,
            "#{singular}_live",
            "registration_test.exs"
          ],
          "login_live.ex": [web_pre, "live", web_path, "#{singular}_live", "login.ex"],
          "login_live_test.exs": [
            web_test_pre,
            "live",
            web_path,
            "#{singular}_live",
            "login_test.exs"
          ],
          "settings_live.ex": [web_pre, "live", web_path, "#{singular}_live", "settings.ex"],
          "settings_live_test.exs": [
            web_test_pre,
            "live",
            web_path,
            "#{singular}_live",
            "settings_test.exs"
          ],
          "confirmation_live.ex": [
            web_pre,
            "live",
            web_path,
            "#{singular}_live",
            "confirmation.ex"
          ],
          "confirmation_live_test.exs": [
            web_test_pre,
            "live",
            web_path,
            "#{singular}_live",
            "confirmation_test.exs"
          ]
        ]

        remap_files(default_files ++ live_files)

      _ ->
        non_live_files = [
          "registration_new.html.heex": [
            controller_pre,
            "#{singular}_registration_html",
            "new.html.heex"
          ],
          "registration_controller.ex": [controller_pre, "#{singular}_registration_controller.ex"],
          "registration_controller_test.exs": [
            web_test_pre,
            "controllers",
            web_path,
            "#{singular}_registration_controller_test.exs"
          ],
          "registration_html.ex": [controller_pre, "#{singular}_registration_html.ex"],
          "session_html.ex": [controller_pre, "#{singular}_session_html.ex"],
          "session_new.html.heex": [controller_pre, "#{singular}_session_html", "new.html.heex"],
          "session_confirm.html.heex": [
            controller_pre,
            "#{singular}_session_html",
            "confirm.html.heex"
          ],
          "settings_html.ex": [web_pre, "controllers", web_path, "#{singular}_settings_html.ex"],
          "settings_controller.ex": [controller_pre, "#{singular}_settings_controller.ex"],
          "settings_edit.html.heex": [
            controller_pre,
            "#{singular}_settings_html",
            "edit.html.heex"
          ],
          "settings_controller_test.exs": [
            web_test_pre,
            "controllers",
            web_path,
            "#{singular}_settings_controller_test.exs"
          ]
        ]

        remap_files(default_files ++ non_live_files)
    end
  end

  defp remap_files(files) do
    for {source, dest} <- files, do: {:eex, to_string(source), Path.join(dest)}
  end

  defp copy_new_files(%Context{} = context, binding, paths) do
    files = files_to_be_generated(binding)
    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.auth", binding, files)
    inject_context_functions(context, paths, binding)
    inject_tests(context, paths, binding)
    inject_context_test_fixtures(context, paths, binding)

    context
  end

  defp inject_context_functions(%Context{file: file} = context, paths, binding) do
    Gen.Context.ensure_context_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/context_functions.ex", binding)
    |> prepend_newline()
    |> inject_before_final_end(file)
  end

  defp inject_tests(%Context{test_file: test_file} = context, paths, binding) do
    Gen.Context.ensure_test_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/test_cases.exs", binding)
    |> prepend_newline()
    |> inject_before_final_end(test_file)
  end

  defp inject_context_test_fixtures(
         %Context{test_fixtures_file: test_fixtures_file} = context,
         paths,
         binding
       ) do
    Gen.Context.ensure_test_fixtures_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/context_fixtures_functions.ex", binding)
    |> prepend_newline()
    |> inject_before_final_end(test_fixtures_file)
  end

  defp inject_conn_case_helpers(%Context{} = context, paths, binding) do
    test_file = "test/support/conn_case.ex"

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/conn_case.exs", binding)
    |> inject_before_final_end(test_file)

    context
  end

  defp inject_routes(%Context{context_app: ctx_app} = context, paths, binding) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    file_path = Path.join(web_prefix, "router.ex")

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/routes.ex", binding)
    |> inject_before_final_end(file_path)

    context
  end

  defp maybe_inject_mix_dependency(%Context{context_app: ctx_app} = context, %HashingLibrary{
         mix_dependency: mix_dependency
       }) do
    file_path = Mix.Phoenix.context_app_path(ctx_app, "mix.exs")

    file = File.read!(file_path)

    case Injector.mix_dependency_inject(file, mix_dependency) do
      {:ok, new_file} ->
        print_injecting(file_path)
        File.write!(file_path, new_file)

      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        Mix.shell().info("""

        Add your #{mix_dependency} dependency to #{file_path}:

            defp deps do
              [
                #{mix_dependency},
                ...
              ]
            end
        """)
    end

    context
  end

  defp maybe_inject_router_import(%Context{context_app: ctx_app} = context, binding) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    file_path = Path.join(web_prefix, "router.ex")
    auth_module = Keyword.fetch!(binding, :auth_module)
    inject = "import #{inspect(auth_module)}"
    use_line = "use #{inspect(context.web_module)}, :router"

    help_text = """
    Add your #{inspect(auth_module)} import to #{Path.relative_to_cwd(file_path)}:

        defmodule #{inspect(context.web_module)}.Router do
          #{use_line}

          # Import authentication plugs
          #{inject}

          ...
        end
    """

    with {:ok, file} <- read_file(file_path),
         {:ok, new_file} <-
           Injector.inject_unless_contains(
             file,
             inject,
             &String.replace(&1, use_line, "#{use_line}\n\n  #{&2}")
           ) do
      print_injecting(file_path, " - imports")
      File.write!(file_path, new_file)
    else
      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        Mix.shell().info("""

        #{help_text}
        """)

      {:error, {:file_read_error, _}} ->
        print_injecting(file_path)
        print_unable_to_read_file_error(file_path, help_text)
    end

    context
  end

  defp maybe_inject_router_plug(%Context{context_app: ctx_app} = context, binding) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    file_path = Path.join(web_prefix, "router.ex")
    help_text = Injector.router_plug_help_text(file_path, binding)

    with {:ok, file} <- read_file(file_path),
         {:ok, new_file} <- Injector.router_plug_inject(file, binding) do
      print_injecting(file_path, " - plug")
      File.write!(file_path, new_file)
    else
      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        Mix.shell().info("""

        #{help_text}
        """)

      {:error, {:file_read_error, _}} ->
        print_injecting(file_path)
        print_unable_to_read_file_error(file_path, help_text)
    end

    context
  end

  defp maybe_inject_app_layout_menu(%Context{} = context, binding) do
    if file_path = get_layout_html_path(context) do
      case Injector.app_layout_menu_inject(binding, File.read!(file_path)) do
        {:ok, new_content} ->
          print_injecting(file_path)
          File.write!(file_path, new_content)

        :already_injected ->
          :ok

        {:error, :unable_to_inject} ->
          Mix.shell().info("""

          #{Injector.app_layout_menu_help_text(file_path, binding)}
          """)
      end
    else
      {_dup, inject} = Injector.app_layout_menu_code_to_inject(binding)

      missing =
        context
        |> potential_layout_file_paths()
        |> Enum.map_join("\n", &"  * #{&1}")

      Mix.shell().error("""

      Unable to find the root layout file to inject user menu items.

      Missing files:

      #{missing}

      Please ensure this phoenix app was not generated with
      --no-html. If you have changed the name of your root
      layout file, please add the following code to it where you'd
      like the #{binding[:schema].singular} menu items to be rendered.

      #{inject}
      """)
    end

    context
  end

  defp get_layout_html_path(%Context{} = context) do
    context
    |> potential_layout_file_paths()
    |> Enum.find(&File.exists?/1)
  end

  defp potential_layout_file_paths(%Context{context_app: ctx_app}) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)

    for file_name <- ~w(root.html.heex) do
      Path.join([web_prefix, "components", "layouts", file_name])
    end
  end

  defp inject_hashing_config(context, %HashingLibrary{} = hashing_library) do
    file_path =
      if Mix.Phoenix.in_umbrella?(File.cwd!()) do
        Path.expand("../../")
      else
        File.cwd!()
      end
      |> Path.join("config/test.exs")

    file =
      case read_file(file_path) do
        {:ok, file} -> file
        {:error, {:file_read_error, _}} -> "import Config\n"
      end

    case Injector.test_config_inject(file, hashing_library) do
      {:ok, new_file} ->
        print_injecting(file_path)
        File.write!(file_path, new_file)

      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        help_text = Injector.test_config_help_text(file_path, hashing_library)

        Mix.shell().info("""

        #{help_text}
        """)
    end

    context
  end

  defp maybe_inject_scope_config(%Context{} = context, binding) do
    if binding[:scope_config].create_new? do
      inject_scope_config(context, binding)
    else
      context
    end
  end

  defp inject_scope_config(%Context{} = context, binding) do
    scope_config = binding[:scope_config].config_string

    file_path =
      if Mix.Phoenix.in_umbrella?(File.cwd!()) do
        Path.expand("../../")
      else
        File.cwd!()
      end
      |> Path.join("config/config.exs")

    file =
      case read_file(file_path) do
        {:ok, file} -> file
        {:error, {:file_read_error, _}} -> "import Config\n"
      end

    case Injector.config_inject(file, scope_config) do
      {:ok, new_file} ->
        print_injecting(file_path)
        File.write!(file_path, new_file)

      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        Mix.shell().info("""
        Add the following to #{Path.relative_to_cwd(file_path)}:

        #{scope_config}
        """)
    end

    context
  end

  defp maybe_inject_agents_md(%Context{} = context, paths, binding) do
    if binding[:agents_md] do
      # we add our own comment marker (not related to usage_rules)
      # to check if phx.gen.auth already ran as we only want to inject once
      # even if other options were used
      auth_content =
        """
        <!-- phoenix-gen-auth-start -->
        #{Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.auth/AGENTS.md", binding)}
        <!-- phoenix-gen-auth-end -->
        """

      file_path =
        if Mix.Phoenix.in_umbrella?(File.cwd!()) do
          Path.expand("../../")
        else
          File.cwd!()
        end
        |> Path.join("AGENTS.md")

      with true <- File.exists?(file_path),
           content = File.read!(file_path),
           false <- content =~ "<!-- phoenix-gen-auth-start -->" do
        print_injecting(file_path)
        # inject before usage rules
        case String.split(content, "<!-- usage-rules-start -->", parts: 2) do
          [pre, post] ->
            File.write!(file_path, [
              pre,
              String.trim_trailing(auth_content),
              "\n\n",
              "<!-- usage-rules-start -->",
              post
            ])

          _ ->
            # just append
            File.write!(file_path, content <> "\n\n" <> String.trim_trailing(auth_content))
        end
      end
    end

    context
  end

  defp print_shell_instructions(%Context{} = context) do
    Mix.shell().info("""

    Please re-fetch your dependencies with the following command:

        $ mix deps.get

    Remember to update your repository by running migrations:

        $ mix ecto.migrate

    Once you are ready, visit "/#{context.schema.plural}/register"
    to create your account and then access "/dev/mailbox" to
    see the account confirmation email.
    """)

    context
  end

  defp router_scope(%Context{schema: schema} = context) do
    prefix = Module.concat(context.web_module, schema.web_namespace)

    if schema.web_namespace do
      ~s|"/#{schema.web_path}", #{inspect(prefix)}|
    else
      ~s|"/", #{inspect(context.web_module)}|
    end
  end

  defp web_path_prefix(%Schema{web_path: nil}), do: ""
  defp web_path_prefix(%Schema{web_path: web_path}), do: "/" <> web_path

  defp inject_before_final_end(content_to_inject, file_path) do
    with {:ok, file} <- read_file(file_path),
         {:ok, new_file} <- Injector.inject_before_final_end(file, content_to_inject) do
      print_injecting(file_path)
      File.write!(file_path, new_file)
    else
      :already_injected ->
        :ok

      {:error, {:file_read_error, _}} ->
        print_injecting(file_path)

        print_unable_to_read_file_error(
          file_path,
          """

          Please add the following to the end of your equivalent
          #{Path.relative_to_cwd(file_path)} module:

          #{indent_spaces(content_to_inject, 2)}
          """
        )
    end
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, file} -> {:ok, file}
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  defp indent_spaces(string, number_of_spaces)
       when is_binary(string) and is_integer(number_of_spaces) do
    indent = String.duplicate(" ", number_of_spaces)

    string
    |> String.split("\n")
    |> Enum.map_join("\n", &(indent <> &1))
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp prepend_newline(string) when is_binary(string), do: "\n" <> string

  defp get_ecto_adapter!(%Schema{repo: repo}) do
    if Code.ensure_loaded?(repo) do
      repo.__adapter__()
    else
      Mix.raise("Unable to find #{inspect(repo)}")
    end
  end

  defp print_injecting(file_path, suffix \\ []) do
    Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path), suffix])
  end

  defp print_unable_to_read_file_error(file_path, help_text) do
    Mix.shell().error(
      """

      Unable to read file #{Path.relative_to_cwd(file_path)}.

      #{help_text}
      """
      |> indent_spaces(2)
    )
  end

  @doc false
  def raise_with_help(msg) do
    raise_with_help(msg, :general)
  end

  defp raise_with_help(msg, :general) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth expects a context module name, followed by
    the schema module and its plural name (used as the schema
    table name).

    For example:

        mix phx.gen.auth Accounts User users

    The context serves as the API boundary for the given resource.
    Multiple resources may belong to a context and a resource may be
    split over distinct contexts (such as Accounts.User and Payments.User).
    """)
  end

  defp raise_with_help(msg, :phx_generator_args) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth must be installed into a Phoenix 1.5 app that
    contains ecto and html templates.

        mix phx.new my_app
        mix phx.new my_app --umbrella
        mix phx.new my_app --database mysql

    Apps generated with --no-ecto or --no-html are not supported.
    """)
  end

  defp raise_with_help(msg, :hashing_lib) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth supports the following values for --hashing-lib

      * bcrypt
      * pbkdf2
      * argon2

    Visit https://github.com/riverrun/comeonin for more information
    on choosing a library.
    """)
  end

  defp test_case_options(Ecto.Adapters.Postgres), do: ", async: true"
  defp test_case_options(adapter) when is_atom(adapter), do: ""

  defp datetime_module(%{timestamp_type: :naive_datetime}), do: NaiveDateTime
  defp datetime_module(%{timestamp_type: :utc_datetime}), do: DateTime
  defp datetime_module(%{timestamp_type: :utc_datetime_usec}), do: DateTime

  defp datetime_now(%{timestamp_type: :naive_datetime}), do: "NaiveDateTime.utc_now(:second)"
  defp datetime_now(%{timestamp_type: :utc_datetime}), do: "DateTime.utc_now(:second)"
  defp datetime_now(%{timestamp_type: :utc_datetime_usec}), do: "DateTime.utc_now()"

  defp put_live_option(schema) do
    opts =
      case Keyword.fetch(schema.opts, :live) do
        {:ok, _live?} ->
          schema.opts

        _ ->
          Mix.shell().info("""
          An authentication system can be created in two different ways:
          - Using Phoenix.LiveView (default)
          - Using Phoenix.Controller only\
          """)

          if Mix.shell().yes?("Do you want to create a LiveView based authentication system?") do
            Keyword.put_new(schema.opts, :live, true)
          else
            Keyword.put_new(schema.opts, :live, false)
          end
      end

    Map.put(schema, :opts, opts)
  end
end
