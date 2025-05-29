defmodule Mix.Phoenix.Scope do
  @moduledoc false

  defstruct name: nil,
            default: false,
            module: nil,
            alias: nil,
            assign_key: nil,
            access_path: nil,
            route_prefix: nil,
            route_access_path: nil,
            schema_table: nil,
            schema_key: nil,
            schema_type: nil,
            schema_migration_type: nil,
            test_data_fixture: nil,
            test_setup_helper: nil

  @doc """
  Creates a new scope struct.
  """
  def new!(name, opts) do
    scope = struct!(__MODULE__, opts)
    alias = Module.concat([scope.module |> Module.split() |> List.last()])

    route_access_path =
      case scope.route_access_path || Enum.drop(scope.access_path, -1) do
        [] -> scope.access_path
        rap -> rap
      end

    %{
      scope
      | name: name,
        alias: alias,
        route_access_path: route_access_path,
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

  @doc """
  Generates a route prefix string with placeholders for the access path.

  Takes a scope_key (what to use for accessing the scope) and a schema with scope information.
  If the schema doesn't have a scope with route_prefix, returns an empty string.
  Otherwise, it processes the route_prefix, replacing param segments with dynamic path elements.

  ## Examples

      scope_route_prefix("socket.assigns.current_scope", schema_with_scope)
      # => "/orgs/\#{socket.assigns.current_scope.organization.slug}"

      scope_route_prefix("@current_scope", schema_with_scope)
      # => "/orgs/\#{@current_scope.organization.slug}"

      scope_route_prefix("scope", schema_with_scope)
      # => "/orgs/\#{scope.organization.slug}"
  """
  def route_prefix(
        scope_key,
        %{scope: %{route_prefix: route_prefix, route_access_path: route_access_path}} = _schema
      )
      when not is_nil(route_prefix) do
    # Replace any path segment that starts with a colon with route_access_path from the scope
    path_segments = String.split(route_prefix, "/", trim: true)
    param_segments = Enum.filter(path_segments, &String.starts_with?(&1, ":"))

    if length(param_segments) > 1 do
      Mix.raise(
        "The route_prefix option in scope configuration must contain only one parameter. Found: #{inspect(param_segments)}"
      )
    end

    path_with_placeholders =
      path_segments
      |> Enum.map(fn segment ->
        if String.starts_with?(segment, ":") do
          # Extract parameter name without the colon
          access_string = Enum.join(route_access_path, ".")
          "\#{#{scope_key}.#{access_string}}"
        else
          segment
        end
      end)
      |> Enum.join("/")

    "/#{path_with_placeholders}"
  end

  def route_prefix(_scope_key, _schema), do: ""
end
