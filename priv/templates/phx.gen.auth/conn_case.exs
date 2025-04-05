
  @doc """
  Setup helper that registers and logs in <%= schema.plural %>.

      setup :register_and_log_in_<%= schema.singular %>

  It stores an updated connection and a registered <%= schema.singular %> in the
  test context.
  """
  def register_and_log_in_<%= schema.singular %>(%{conn: conn} = context) do
    <%= schema.singular %> = <%= inspect context.module %>Fixtures.<%= schema.singular %>_fixture()
    scope = <%= inspect scope_config.scope.module %>.for_<%= schema.singular %>(<%= schema.singular %>)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_<%= schema.singular %>(conn, <%= schema.singular %>, opts), <%= schema.singular %>: <%= schema.singular %>, scope: scope}
  end

  @doc """
  Logs the given `<%= schema.singular %>` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_<%= schema.singular %>(conn, <%= schema.singular %>, opts \\ []) do
    token = <%= inspect context.module %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:<%= schema.singular %>_token, token)
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    <%= inspect context.module %>Fixtures.override_token_authenticated_at(token, authenticated_at)
  end
