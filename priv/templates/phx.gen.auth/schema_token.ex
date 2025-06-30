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
  @session_validity_in_days 14
<%= if schema.binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id<% end %>
  schema "<%= schema.table %>_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :authenticated_at, <%= inspect schema.timestamp_type %>
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
    dt = <%= schema.singular %>.authenticated_at || <%= datetime_now %>
    {token, %<%= inspect schema.alias %>Token{token: token, context: "session", <%= schema.singular %>_id: <%= schema.singular %>.id, authenticated_at: dt}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the <%= schema.singular %> found by the token, if any, along with the token's creation time.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: <%= schema.singular %> in assoc(token, :<%= schema.singular %>),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{<%= schema.singular %> | authenticated_at: token.authenticated_at}, token.inserted_at}

    {:ok, query}
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

  defp by_token_and_context_query(token, context) do
    from <%= inspect schema.alias %>Token, where: [token: ^token, context: ^context]
  end
end
