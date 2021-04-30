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
      iex> token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user auth", user_id)
      iex> Phoenix.Token.verify(MyAppWeb.Endpoint, "user auth", token, max_age: 86400)
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
      to provide adequate entropy

  The second argument is a [cryptographic salt](https://en.wikipedia.org/wiki/Salt_(cryptography))
  which must be the same in both calls to `sign/4` and `verify/4`.
  For instance, it may be called "user auth" and treated as namespace
  when generating a token that will be used to authenticate users on
  channels or on your APIs.

  The third argument can be any term (string, int, list, etc.)
  that you wish to codify into the token. Upon valid verification,
  this same term will be extracted from the token.

  ## Usage

  Once a token is signed, we can send it to the client in multiple ways.

  One is via the meta tag:

      <%= tag :meta, name: "channel_token",
                     content: Phoenix.Token.sign(@conn, "user auth", @current_user.id) %>

  Or an endpoint that returns it:

      def create(conn, params) do
        user = User.create(params)
        render(conn, "user.json",
               %{token: Phoenix.Token.sign(conn, "user auth", user.id), user: user})
      end

  Once the token is sent, the client may now send it back to the server
  as an authentication mechanism. For example, we can use it to authenticate
  a user on a Phoenix channel:

      defmodule MyApp.UserSocket do
        use Phoenix.Socket

        def connect(%{"token" => token}, socket, _connect_info) do
          case Phoenix.Token.verify(socket, "user auth", token, max_age: 86400) do
            {:ok, user_id} ->
              socket = assign(socket, :user, Repo.get!(User, user_id))
              {:ok, socket}
            {:error, _} ->
              :error
          end
        end

        def connect(_params, _socket, _connect_info), do: :error
      end

  In this example, the phoenix.js client will send the token in the
  `connect` command which is then validated by the server.

  `Phoenix.Token` can also be used for validating APIs, handling
  password resets, e-mail confirmation and more.
  """

  require Logger

  @doc """
  Encodes  and signs data into a token you can send to clients.

  ## Options

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`
    * `:signed_at` - set the timestamp of the token in seconds.
      Defaults to `System.system_time(:second)`

  """
  def sign(context, salt, data, opts \\ []) when is_binary(salt) do
    context
    |> get_key_base()
    |> Plug.Crypto.sign(salt, data, opts)
  end

  @doc """
  Encodes, encrypts, and signs data into a token you can send to clients.

  ## Options

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`
    * `:signed_at` - set the timestamp of the token in seconds.
      Defaults to `System.system_time(:second)`

  """
  def encrypt(context, secret, data, opts \\ []) when is_binary(secret) do
    context
    |> get_key_base()
    |> Plug.Crypto.encrypt(secret, data, opts)
  end

  @doc """
  Decodes the original data from the token and verifies its integrity.

  ## Examples

  In this scenario we will create a token, sign it, then provide it to a client
  application. The client will then use this token to authenticate requests for
  resources from the server. See `Phoenix.Token` summary for more info about
  creating tokens.

      iex> user_id    = 99
      iex> secret     = "kjoy3o1zeidquwy1398juxzldjlksahdk3"
      iex> namespace  = "user auth"
      iex> token      = Phoenix.Token.sign(secret, namespace, user_id)

  The mechanism for passing the token to the client is typically through a
  cookie, a JSON response body, or HTTP header. For now, assume the client has
  received a token it can use to validate requests for protected resources.

  When the server receives a request, it can use `verify/4` to determine if it
  should provide the requested resources to the client:

      iex> Phoenix.Token.verify(secret, namespace, token, max_age: 86400)
      {:ok, 99}

  In this example, we know the client sent a valid token because `verify/4`
  returned a tuple of type `{:ok, user_id}`. The server can now proceed with
  the request.

  However, if the client had sent an expired or otherwise invalid token
  `verify/4` would have returned an error instead:

      iex> Phoenix.Token.verify(secret, namespace, expired, max_age: 86400)
      {:error, :expired}

      iex> Phoenix.Token.verify(secret, namespace, invalid, max_age: 86400)
      {:error, :invalid}

  ## Options

    * `:max_age` - verifies the token only if it has been generated
      "max age" ago in seconds. A reasonable value is 1 day (86400
      seconds)
    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`

  """
  def verify(context, salt, token, opts \\ []) when is_binary(salt) do
    context
    |> get_key_base()
    |> Plug.Crypto.verify(salt, token, opts)
  end

  @doc """
  Decrypts the original data from the token and verifies its integrity.

  ## Options

    * `:max_age` - verifies the token only if it has been generated
      "max age" ago in seconds. A reasonable value is 1 day (86400
      seconds)
    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`

  """
  def decrypt(context, secret, token, opts \\ []) when is_binary(secret) do
    context
    |> get_key_base()
    |> Plug.Crypto.decrypt(secret, token, opts)
  end

  ## Helpers

  defp get_key_base(%Plug.Conn{} = conn),
    do: conn |> Phoenix.Controller.endpoint_module() |> get_endpoint_key_base()

  defp get_key_base(%Phoenix.Socket{} = socket),
    do: get_endpoint_key_base(socket.endpoint)

  defp get_key_base(endpoint) when is_atom(endpoint),
    do: get_endpoint_key_base(endpoint)

  defp get_key_base(string) when is_binary(string) and byte_size(string) >= 20,
    do: string

  defp get_endpoint_key_base(endpoint) do
    endpoint.config(:secret_key_base) ||
      raise """
      no :secret_key_base configuration found in #{inspect(endpoint)}.
      Ensure your environment has the necessary mix configuration. For example:

          config :my_app, MyAppWeb.Endpoint,
              secret_key_base: ...

      """
  end
end
