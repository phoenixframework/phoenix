
  @doc """
  Setup helper that registers and logs in <%= schema.plural %>.

      setup :register_and_log_in_<%= schema.singular %>

  It stores an updated connection and a registered <%= schema.singular %> in the
  test context.
  """
  def register_and_log_in_<%= schema.singular %>(%{conn: conn}) do
    <%= schema.singular %> = <%= inspect context.module %>Fixtures.<%= schema.singular %>_fixture()
    %{conn: log_in_<%= schema.singular %>(conn, <%= schema.singular %>), <%= schema.singular %>: <%= schema.singular %>}
  end

  @doc """
  Logs the given `<%= schema.singular %>` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_<%= schema.singular %>(conn, <%= schema.singular %>) do
    token = <%= inspect context.module %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:<%= schema.singular %>_token, token)
  end
