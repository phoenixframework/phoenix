defmodule <%= inspect schema.module %>Token do
  use Ecto.Schema
  import Ecto.Query
  alias <%= inspect schema.module %>Token

  @hash_algorithm :sha256
  @rand_size 32

  # It is very important to keep the magic link token expiry short,
  # since someone with access to the email may take over the account.
  @magic_link_validity_in_minutes 15
  @change_email_validity_in_days 7
  @session_validity_in_days 60
<%= if schema.binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id<% end %>
  schema "<%= schema.table %>_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :refreshed_at, :utc_datetime
    belongs_to :<%= schema.singular %>, <%= inspect schema.module %>

    timestamps(<%= if schema.timestamp_type != :naive_datetime, do: "type: #{inspect schema.timestamp_type}, " %>updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual <%= schema.singular %>
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(<%= schema.singular %>) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {token,
     %<%= inspect schema.alias %>Token{
       token: token,
       context: "session",
       <%= schema.singular %>_id: <%= schema.singular %>.id,
       refreshed_at: DateTime.utc_now(:second)
     }}
  end

  @doc """
  Returns the number of seconds since the <%= schema.singular %> token was last refreshed.

  This is mainly for use with "session" tokens. If the token is a session
  token that has never refreshed, it returns `0`.

  All other token types return `nil`.
  """
  def seconds_since_refresh(%<%= inspect schema.alias %>Token{context: "session", refreshed_at: nil}), do: 0

  def seconds_since_refresh(%<%= inspect schema.alias %>Token{context: "session", refreshed_at: refreshed_at}) do
    DateTime.diff(DateTime.utc_now(:second), refreshed_at, :second)
  end

  def seconds_since_refresh(%<%= inspect schema.alias %>Token{refreshed_at: nil}), do: nil

  @doc """
  Returns a query for all valid session <%= inspect schema.alias %>Tokens for the given token.

  The token is valid if it matches the value in the database, it has
  a <%= schema.singular %> attached to it, and it has been refreshed in the last
  @session_validity_in_days days.
  """
  def valid_<%= schema.singular %>_token_query(token) do
    from token in by_token_and_context_query(token, "session"),
      join: <%= schema.singular %> in assoc(token, :<%= schema.singular %>),
      where: token.refreshed_at > ago(@session_validity_in_days, "day")
  end

  @doc """
  Returns a query for all valid session <%= inspect schema.alias %>Tokens for the given token,
  along with the related <%= inspect schema.alias %> in a tuple.

  The query will return nothing if the token is invalid or the <%= schema.singular %> is not found.

  The token is valid if it matches the value in the database, it has
  a <%= schema.singular %> attached to it, and it has been refreshed in the last
  @session_validity_in_days days.
  """
  def valid_<%= schema.singular %>_auth_query(token) do
    from [token, <%= schema.singular %>] in valid_<%= schema.singular %>_token_query(token),
      select: {token, %{<%= schema.singular %> | authenticated_at: token.inserted_at}}
  end

  @doc """
  Returns a query for <%= schema.plural %> with valid sessions for the given token.

  The token is valid if it matches the value in the database, it has
  a <%= schema.singular %> attached to it, and it has been refreshed in the last
  @session_validity_in_days days.
  """
  def valid_session_token_query(token) do
    from [token, <%= schema.singular %>] in valid_<%= schema.singular %>_token_query(token),
      select: <%= schema.singular %>,
      select_merge: %{authenticated_at: token.inserted_at}
  end

  @doc """
  Builds a token and its hash to be delivered to the <%= schema.singular %>'s email.

  The non-hashed token is sent to the <%= schema.singular %> email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the <%= schema.singular %> changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  def build_email_token(<%= schema.singular %>, context) do
    build_hashed_token(<%= schema.singular %>, context, <%= schema.singular %>.email)
  end

  defp build_hashed_token(<%= schema.singular %>, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %<%= inspect schema.alias %>Token{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       <%= schema.singular %>_id: <%= schema.singular %>.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  If found, the query returns a tuple of the form `{<%= schema.singular %>, token}`.

  The given token is valid if it matches its hashed counterpart in the
  database. This function also checks if the token is being used within
  15 minutes. The context of a magic link token is always "login".
  """
  def verify_magic_link_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "login"),
            join: <%= schema.singular %> in assoc(token, :<%= schema.singular %>),
            where: token.inserted_at > ago(^@magic_link_validity_in_minutes, "minute"),
            where: token.sent_to == <%= schema.singular %>.email,
            select: {<%= schema.singular %>, token}

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the <%= schema.singular %>_token found by the token, if any.

  This is used to validate requests to change the <%= schema.singular %>
  email.
  The given token is valid if it matches its hashed counterpart in the
  database and if it has not expired (after @change_email_validity_in_days).
  The context must always start with "change:".
  """
  def verify_change_email_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def by_token_and_context_query(token, context) do
    from <%= inspect schema.alias %>Token, where: [token: ^token, context: ^context]
  end

  @doc """
  Gets all tokens for the given <%= schema.singular %> for the given contexts.
  """
  def by_<%= schema.singular %>_and_contexts_query(<%= schema.singular %>, :all) do
    from t in <%= inspect schema.alias %>Token, where: t.<%= schema.singular %>_id == ^<%= schema.singular %>.id
  end

  def by_<%= schema.singular %>_and_contexts_query(<%= schema.singular %>, [_ | _] = contexts) do
    from t in <%= inspect schema.alias %>Token, where: t.<%= schema.singular %>_id == ^<%= schema.singular %>.id and t.context in ^contexts
  end

  @doc """
  Deletes a list of tokens.
  """
  def delete_all_query(tokens) do
    from t in <%= inspect schema.alias %>Token, where: t.id in ^Enum.map(tokens, & &1.id)
  end

  @doc """
  Returns a query that returns all expired tokens for the given context.

  The context must be one of the following:
  - "login"
  - "session"
  - "change_email"
  """
  def expired_tokens_for_context_query("login") do
    from t in <%= inspect schema.alias %>Token,
      where:
        t.context == "login" and
          t.inserted_at < ago(^@magic_link_validity_in_minutes, "minute")
  end

  def expired_tokens_for_context_query("session") do
    from t in <%= inspect schema.alias %>Token,
      where:
        t.context == "session" and
          (is_nil(t.refreshed_at) or t.refreshed_at < ago(@session_validity_in_days, "day"))
  end

  def expired_tokens_for_context_query("change_email") do
    from t in <%= inspect schema.alias %>Token,
      where:
        like(t.context, "change:%") and
          t.inserted_at < ago(@change_email_validity_in_days, "day")
  end
end
