defmodule Mix.Phoenix.Scope do
  @moduledoc false

  defstruct name: nil,
            default: false,
            module: nil,
            alias: nil,
            assign_key: nil,
            access_path: nil,
            schema_key: nil,
            schema_type: nil

  @doc """
  Creates a new scope struct.
  """
  def new!(name, opts) do
    scope = struct!(__MODULE__, opts)
    alias = Module.concat([scope.module |> Module.split() |> List.last()])

    %{scope | name: name, alias: alias}
  end

  @doc """
  Returns a `%{name: scope}` map of configured scopes.
  """
  def scopes_from_config do
    scopes = Application.get_env(:phoenix, :scopes, [])

    Map.new(scopes, fn {name, opts} -> {name, new!(name, opts)} end)
  end

  @doc """
  Returns the default scope.
  """
  def default_scope do
    with {_, scope} <- Enum.find(scopes_from_config(), fn {_, scope} -> scope.default end) do
      scope
    end
  end

  @doc """
  Returns the configured scope for the given --scope parameter.

  Returns `nil` for `--no-scope` and raises if a specific scope is not configured.
  """
  def scope_from_opts(bin, false) when is_binary(bin) do
    raise "--scope and --no-scope must not be used together"
  end

  def scope_from_opts(_, true), do: nil

  def scope_from_opts(nil, _) do
    default_scope() || raise """
    no default scope configured!

    Either run the generator with --no-scope to skip scoping, specify a scope with --scope,
    or configure a default scope in your application's config:

        config :phoenix, :scopes, [
          user: [
            default: true,
            ...
          ]
        ]
    """
  end

  def scope_from_opts(name, _) do
    key = String.to_atom(name)
    scopes = scopes_from_config()
    Map.get_lazy(scopes, key, fn ->
      raise """
      scope :#{key} not configured!

      Ensure that the scope :#{key} is configured in your application's config:

          config :phoenix, :scopes, [
            #{key}: [
              ...
            ]
          ]

      Note that phx.gen.auth generates a default scope for you.
      """
    end)
  end
end
