  alias <%= inspect context.module %>.{<%= inspect schema.alias %>, <%= inspect schema.alias %>Token, <%= inspect schema.alias %>Notifier}

  ## Database getters

  @doc """
  Gets a <%= schema.singular %> by email.

  ## Examples

      iex> get_<%= schema.singular %>_by_email("foo@example.com")
      %<%= inspect schema.alias %>{}

      iex> get_<%= schema.singular %>_by_email("unknown@example.com")
      nil

  """
  def get_<%= schema.singular %>_by_email(email) when is_binary(email) do
    Repo.get_by(<%= inspect schema.alias %>, email: email)
  end

  @doc """
  Gets a <%= schema.singular %> by email and password.

  ## Examples

      iex> get_<%= schema.singular %>_by_email_and_password("foo@example.com", "correct_password")
      %<%= inspect schema.alias %>{}

      iex> get_<%= schema.singular %>_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_<%= schema.singular %>_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    <%= schema.singular %> = Repo.get_by(<%= inspect schema.alias %>, email: email)
    if <%= inspect schema.alias %>.valid_password?(<%= schema.singular %>, password), do: <%= schema.singular %>
  end

  @doc """
  Gets a single <%= schema.singular %>.

  Raises `Ecto.NoResultsError` if the <%= inspect schema.alias %> does not exist.

  ## Examples

      iex> get_<%= schema.singular %>!(123)
      %<%= inspect schema.alias %>{}

      iex> get_<%= schema.singular %>!(456)
      ** (Ecto.NoResultsError)

  """
  def get_<%= schema.singular %>!(id), do: Repo.get!(<%= inspect schema.alias %>, id)

  ## <%= schema.human_singular %> registration

  @doc """
  Registers a <%= schema.singular %>.

  ## Examples

      iex> register_<%= schema.singular %>(%{field: value})
      {:ok, %<%= inspect schema.alias %>{}}

      iex> register_<%= schema.singular %>(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_<%= schema.singular %>(attrs) do
    %<%= inspect schema.alias %>{}
    |> <%= inspect schema.alias %>.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the <%= schema.singular %> is in sudo mode.

  The <%= schema.singular %> is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(<%= schema.singular %>, minutes \\ -20)

  def sudo_mode?(%<%= inspect schema.alias %>{authenticated_at: ts}, minutes) when is_struct(ts, <%= inspect datetime_module %>) do
    <%= inspect datetime_module %>.after?(ts, <%= inspect datetime_module %>.utc_now() |> <%= inspect datetime_module %>.add(minutes, :minute))
  end

  def sudo_mode?(_<%= schema.singular %>, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the <%= schema.singular %> email.

  See `<%= inspect context.module %>.<%= inspect schema.alias %>.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_<%= schema.singular %>_email(<%= schema.singular %>)
      %Ecto.Changeset{data: %<%= inspect schema.alias %>{}}

  """
  def change_<%= schema.singular %>_email(<%= schema.singular %>, attrs \\ %{}, opts \\ []) do
    <%= inspect schema.alias %>.email_changeset(<%= schema.singular %>, attrs, opts)
  end

  @doc """
  Updates the <%= schema.singular %> email using the given token.

  If the token matches, the <%= schema.singular %> email is updated and the token is deleted.
  """
  def update_<%= schema.singular %>_email(<%= schema.singular %>, token) do
    context = "change:#{<%= schema.singular %>.email}"

    Repo.transact(fn ->
      with {:ok, query} <- <%= inspect schema.alias %>Token.verify_change_email_token_query(token, context),
           %<%= inspect schema.alias %>Token{sent_to: email} <- Repo.one(query),
           {:ok, <%= schema.singular %>} <- Repo.update(<%= inspect schema.alias %>.email_changeset(<%= schema.singular %>, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(<%= inspect schema.alias %>Token, where: [<%= schema.singular %>_id: ^<%= schema.singular %>.id, context: ^context])) do
        {:ok, <%= schema.singular %>}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the <%= schema.singular %> password.

  See `<%= inspect context.module %>.<%= inspect schema.alias %>.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_<%= schema.singular %>_password(<%= schema.singular %>)
      %Ecto.Changeset{data: %<%= inspect schema.alias %>{}}

  """
  def change_<%= schema.singular %>_password(<%= schema.singular %>, attrs \\ %{}, opts \\ []) do
    <%= inspect schema.alias %>.password_changeset(<%= schema.singular %>, attrs, opts)
  end

  @doc """
  Updates the <%= schema.singular %> password.

  Returns a tuple with the updated <%= schema.singular %>, as well as a list of expired tokens.

  ## Examples

      iex> update_<%= schema.singular %>_password(<%= schema.singular %>, %{password: ...})
      {:ok, {%<%= inspect schema.alias %>{}, [...]}}

      iex> update_<%= schema.singular %>_password(<%= schema.singular %>, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_<%= schema.singular %>_password(<%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> <%= inspect schema.alias %>.password_changeset(attrs)
    |> update_<%= schema.singular %>_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_<%= schema.singular %>_session_token(<%= schema.singular %>) do
    {token, <%= schema.singular %>_token} = <%= inspect schema.alias %>Token.build_session_token(<%= schema.singular %>)
    Repo.insert!(<%= schema.singular %>_token)
    token
  end

  @doc """
  Gets the <%= schema.singular %> with the given signed token.

  If the token is valid `{<%= schema.singular %>, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_<%= schema.singular %>_by_session_token(token) do
    {:ok, query} = <%= inspect schema.alias %>Token.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the <%= schema.singular %> with the given magic link token.
  """
  def get_<%= schema.singular %>_by_magic_link_token(token) do
    with {:ok, query} <- <%= inspect schema.alias %>Token.verify_magic_link_token_query(token),
         {<%= schema.singular %>, _token} <- Repo.one(query) do
      <%= schema.singular %>
    else
      _ -> nil
    end
  end

  @doc """
  Logs the <%= schema.singular %> in by magic link.

  There are three cases to consider:

  1. The <%= schema.singular %> has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The <%= schema.singular %> has not confirmed their email and no password is set.
     In this case, the <%= schema.singular %> gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The <%= schema.singular %> has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_<%= schema.singular %>_by_magic_link(token) do
    {:ok, query} = <%= inspect schema.alias %>Token.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%<%= inspect schema.alias %>{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%<%= inspect schema.alias %>{confirmed_at: nil} = <%= schema.singular %>, _token} ->
        <%= schema.singular %>
        |> <%= inspect schema.alias %>.confirm_changeset()
        |> update_<%= schema.singular %>_and_delete_all_tokens()

      {<%= schema.singular %>, token} ->
        Repo.delete!(token)
        {:ok, {<%= schema.singular %>, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given <%= schema.singular %>.

  ## Examples

      iex> deliver_<%= schema.singular %>_update_email_instructions(<%= schema.singular %>, current_email, &url(~p"<%= schema.route_prefix %>/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_<%= schema.singular %>_update_email_instructions(%<%= inspect schema.alias %>{} = <%= schema.singular %>, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, <%= schema.singular %>_token} = <%= inspect schema.alias %>Token.build_email_token(<%= schema.singular %>, "change:#{current_email}")

    Repo.insert!(<%= schema.singular %>_token)
    <%= inspect schema.alias %>Notifier.deliver_update_email_instructions(<%= schema.singular %>, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given <%= schema.singular %>.
  """
  def deliver_login_instructions(%<%= inspect schema.alias %>{} = <%= schema.singular %>, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, <%= schema.singular %>_token} = <%= inspect schema.alias %>Token.build_email_token(<%= schema.singular %>, "login")
    Repo.insert!(<%= schema.singular %>_token)
    <%= inspect schema.alias %>Notifier.deliver_login_instructions(<%= schema.singular %>, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_<%= schema.singular %>_session_token(token) do
    Repo.delete_all(from(<%= inspect schema.alias %>Token, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_<%= schema.singular %>_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, <%= schema.singular %>} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)

        Repo.delete_all(from(t in <%= inspect schema.alias %>Token, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {<%= schema.singular %>, tokens_to_expire}}
      end
    end)
  end
