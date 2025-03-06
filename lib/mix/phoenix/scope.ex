defmodule Mix.Phoenix.Scope do
  @moduledoc false

  defstruct name: nil,
            default: false,
            module: nil,
            alias: nil,
            assign_key: nil,
            access_path: nil,
            schema_table: nil,
            schema_key: nil,
            schema_type: nil,
            schema_migration_type: nil,
            test_data_fixture: nil,
            test_login_helper: nil

  @doc """
  Creates a new scope struct.
  """
  def new!(name, opts) do
    scope = struct!(__MODULE__, opts)
    alias = Module.concat([scope.module |> Module.split() |> List.last()])

    %{
      scope
      | name: name,
        alias: alias,
        schema_migration_type: scope.schema_migration_type || scope.schema_type
    }
  end

  @doc """
  Returns a `%{name: scope}` map of configured scopes.
  """
  def scopes_from_config(otp_app) do
    scopes = Application.get_env(otp_app, :scopes, [])

    Map.new(scopes, fn {name, opts} -> {name, new!(name, opts)} end)
  end

  @doc """
  Returns the default scope.
  """
  def default_scope(otp_app) do
    case Enum.filter(scopes_from_config(otp_app), fn {_, scope} -> scope.default end) do
      [{_name, scope}] ->
        scope

      [_ | _] = scopes ->
        Mix.raise("""
        There can only be one default scope defined on your application, got:

            * #{Enum.map(scopes, fn {name, _scope} -> name end) |> Enum.join("\n    * ")}
        """)

      [] ->
        nil
    end
  end

  @doc """
  Returns the configured scope for the given --scope parameter.

  Returns `nil` for `--no-scope` and raises if a specific scope is not configured.
  """
  def scope_from_opts(_otp_app, bin, false) when is_binary(bin) do
    Mix.raise("The --scope and --no-scope options must not be used together")
  end

  def scope_from_opts(_otp_app, _name, true), do: nil

  def scope_from_opts(otp_app, nil, _), do: default_scope(otp_app)

  def scope_from_opts(otp_app, name, _) do
    key = String.to_atom(name)
    scopes = scopes_from_config(otp_app)

    Map.get_lazy(scopes, key, fn ->
      Mix.raise("""
      Scope :#{key} not configured!

      Ensure that the scope :#{key} is configured in your application's config:

          config :#{otp_app}, :scopes, [
            #{key}: [
              ...
            ]
          ]

      Note that phx.gen.auth generates a default scope for you.
      """)
    end)
  end
end
