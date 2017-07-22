defmodule Phoenix.Token do
  @moduledoc """
  Tokens provide a way to generate and verify bearer
  tokens for use in Channels or API authentication.

  The data stored in the token is signed to prevent tampering
  but not encrypted. This means it is safe to store identification
  information (such as user IDs) but should not be used to store
  confidential information (such as credit card numbers).

  ## Example

  When generating a unique token for use in an API or Channel
  it is advised to use a unique identifier for the user, typically
  the id from a database. For example:

      iex> user_id = 1
      iex> token = Phoenix.Token.sign(MyApp.Endpoint, "user salt", user_id)
      iex> Phoenix.Token.verify(MyApp.Endpoint, "user salt", token, max_age: 86400)
      {:ok, 1}

  In that example we have a user's id, we generate a token and
  verify it using the secret key base configured in the given
  `endpoint`. We guarantee the token will only be valid for one day
  by setting a max age (recommended).

  The first argument to both `sign/4` and `verify/4` can be one of:

    * the module name of a Phoenix endpoint (shown above) - where
      the secret key base is extracted from the endpoint
    * `Plug.Conn` - where the secret key base is extracted from the
      endpoint stored in the connection
    * `Phoenix.Socket` - where the secret key base is extracted from
      the endpoint stored in the socket
    * a string, representing the secret key base itself. A key base
      with at least 20 randomly generated characters should be used
      to provide adequate entropy.

  The second argument is a [cryptographic salt](https://en.wikipedia.org/wiki/Salt_(cryptography))
  which must be the same in both calls to `sign/4` and `verify/4`.
  For instance, it may be called "user auth" when generating a token
  that will be used to authenticate users on channels or on your APIs.

  The third argument can be any term (string, int, list, etc.)
  that you wish to codify into the token. Upon valid verification,
  this same term will be extracted from the token.

  ## Usage

  Once a token is signed, we can send it to the client in multiple ways.

  One is via the meta tag:

      <%= tag :meta, name: "channel_token",
                     content: Phoenix.Token.sign(@conn, "user salt", @current_user.id) %>

  Or an endpoint that returns it:

      def create(conn, params) do
        user = User.create(params)
        render conn, "user.json",
               %{token: Phoenix.Token.sign(conn, "user salt", user.id), user: user}
      end

  Once the token is sent, the client may now send it back to the server
  as an authentication mechanism. For example, we can use it to authenticate
  a user on a Phoenix channel:

      defmodule MyApp.UserSocket do
        use Phoenix.Socket

        def connect(%{"token" => token}, socket) do
          case Phoenix.Token.verify(socket, "user salt", token, max_age: 86400) do
            {:ok, user_id} ->
              socket = assign(socket, :user, Repo.get!(User, user_id))
              {:ok, socket}
            {:error, _} ->
              :error
          end
        end
      end

  In this example, the phoenix.js client will send the token in the
  `connect` command which is then validated by the server.

  `Phoenix.Token` can also be used for validating APIs, handling
  password resets, e-mail confirmation and more.
  """

  require Logger
  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier

  @doc """
  Encodes data and signs it resulting in a token you can send to clients.

  ## Options

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`
    * `:signed_at` - set the timestamp of the token in seconds.
      Defaults to `System.system_time(:seconds)`
  """
  def sign(context, salt, data, opts \\ []) when is_binary(salt) do
    {signed_at_seconds, key_opts} = Keyword.pop(opts, :signed_at)
    signed_at_ms = if signed_at_seconds, do: trunc(signed_at_seconds * 1000), else: now_ms()
    secret = get_key_base(context) |> get_secret(salt, key_opts)

    %{data: data, signed: signed_at_ms}
    |> :erlang.term_to_binary()
    |> MessageVerifier.sign(secret)
  end

  @doc """
  Decodes the original data from the token and verifies its integrity.

  ## Examples

  In this scenario we will create a token, sign it, then provide it to a client
  application. The client will then use this token to authenticate requests for
  resources from the server. (See `Phoenix.Token` summary for more info about
  creating tokens.)

      iex> user_id    = 99
      iex> secret     = "kjoy3o1zeidquwy1398juxzldjlksahdk3"
      iex> user_salt  = "user salt"
      iex> token      = Phoenix.Token.sign(secret, user_salt, user_id)

  The mechanism for passing the token to the client is typically through a
  cookie, a JSON response body, or HTTP header. For now, assume the client has
  received a token it can use to validate requests for protected resources.

  When the server receives a request, it can use `verify/4` to determine if it
  should provide the requested resources to the client:

      iex> Phoenix.Token.verify(secret, user_salt, token, max_age: 86400)
      {:ok, 99}

  In this example, we know the client sent a valid token because `verify/4`
  returned a tuple of type `{:ok, user_id}`. The server can now proceed with
  the request.

  However, if the client had sent an expired or otherwise invalid token
  `verify/4` would have returned an error instead:

      iex> Phoenix.Token.verify(secret, user_salt, expired, max_age: 86400)
      {:error, :expired}

      iex> Phoenix.Token.verify(secret, user_salt, invalid, max_age: 86400)
      {:error, :invalid}

  ## Options

    * `:max_age` - verifies the token only if it has been generated
      "max age" ago in seconds. A reasonable value is 1 day (`86400`
      seconds)
    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`

  """
  def verify(context, salt, token, opts \\ [])

  def verify(context, salt, token, opts) when is_binary(salt) and is_binary(token) do
    secret = context |> get_key_base() |> get_secret(salt, opts)

    max_age_ms =
      if max_age_secs = opts[:max_age] do
        trunc(max_age_secs * 1000)
      else
        Logger.warn ":max_age was not set on Phoenix.Token.verify/4. " <>
                    "A max_age is recommended otherwise tokens are forever valid. " <>
                    "Please set it to the amount of seconds the token is valid, such as 86400 (1 day)"
        nil
      end

    case MessageVerifier.verify(token, secret) do
      {:ok, message} ->
        %{data: data, signed: signed} = Plug.Crypto.safe_binary_to_term(message)

        if max_age_ms && (signed + max_age_ms) < now_ms() do
          {:error, :expired}
        else
          {:ok, data}
        end
      :error ->
        {:error, :invalid}
    end
  end

  def verify(_context, salt, nil, _opts) when is_binary(salt) do
    {:error, :missing}
  end

  defp get_key_base(%Plug.Conn{} = conn),
    do: conn |> Phoenix.Controller.endpoint_module() |> get_endpoint_key_base()
  defp get_key_base(%Phoenix.Socket{} = socket),
    do: socket.endpoint.config(:secret_key_base)
  defp get_key_base(endpoint) when is_atom(endpoint),
    do: get_endpoint_key_base(endpoint)
  defp get_key_base(string) when is_binary(string) and byte_size(string) >= 20,
    do: string

  defp get_endpoint_key_base(endpoint) do
    endpoint.config(:secret_key_base) || raise """
    no :secret_key_base configuration found in #{inspect endpoint}.
    Ensure your environment has the necessary mix configuration. For example:

        config :my_app, MyApp.Endpoint,
            secret_key_base: ...
    """
  end

  # Gathers configuration and generates the key secrets and signing secrets.
  defp get_secret(secret_key_base, salt, opts) do
    iterations = Keyword.get(opts, :key_iterations, 1000)
    length = Keyword.get(opts, :key_length, 32)
    digest = Keyword.get(opts, :key_digest, :sha256)
    key_opts = [iterations: iterations,
                length: length,
                digest: digest,
                cache: Plug.Keys]
    KeyGenerator.generate(secret_key_base, salt, key_opts)
  end

  defp now_ms, do: System.system_time(:milliseconds)
end
