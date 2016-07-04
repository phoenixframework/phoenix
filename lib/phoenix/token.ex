defmodule Phoenix.Token do
  @moduledoc """
  Tokens provide a way to generate and verify bearer
  tokens for use in Channels or API authentication.

  The data can be read by clients, but the message is
  signed to prevent tampering.

  ## Example

  When generating a unique token for usage in an API or Channel
  it is advised to use a unique identifier for the user typically
  the id from a database. For example:

      iex> user_id = 1
      iex> token = Phoenix.Token.sign(MyApp.Endpoint, "user", user_id)
      iex> Phoenix.Token.verify(MyApp.Endpoint, "user", token)
      {:ok, 1}

  In that example we have a user's id, we generate a token and
  verify it using the secret key base configured in the given
  `endpoint`.

  The first argument to both `sign/4` and `verify/4` can be one of:

    * the module name of a Phoenix endpoint (shown above) - where
      the secret key base is extracted from the endpoint
    * `Plug.Conn` - where the secret key base is extracted from the
      endpoint stored in the connection
    * `Phoenix.Socket` - where the secret key base is extracted from
      the endpoint stored in the socket
    * a string, representing the secret key base itself. We recommend
      a key base with at least 20 characters to provide enough entropy

  ## Usage

  Once a token is signed, we can send it to the client in multiple ways.

  One is via the meta tag:

      <%= tag :meta, name: "channel_token",
                     content: Phoenix.Token.sign(@conn, "user", @current_user.id) %>

  Or an endpoint that returns it:

      def create(conn, params) do
        user = User.create(params)
        render conn, "user.json",
               %{token: Phoenix.Token.sign(conn, "user", user.id), user: user}
      end

  Once the token is sent, the client may now send it back to the server
  as an authentication mechanism. For example, we can use it to authenticate
  a user on a Phoenix channel:

      defmodule MyApp.UserSocket do
        use Phoenix.Socket

        def connect(%{"token" => token}, socket) do
          # Max age of 2 weeks (1209600 seconds)
          case Phoenix.Token.verify(socket, "user", token, max_age: 1209600) do
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

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier

  @doc """
  Encodes data and signs it resulting in a token you can send down to clients.

  ## Options
    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000;
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32;
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256';
  """
  def sign(context, salt, data, opts \\ []) when is_binary(salt) do
    secret = get_key_base(context) |> get_secret(salt, opts)

    message = %{
      data: data,
      signed: now_ms(),
    } |> :erlang.term_to_binary()
    MessageVerifier.sign(message, secret)
  end

  @doc """
  Decodes the original data from the token and verifies its integrity.

  ## Options

    * `:max_age` - verifies the token only if it has been generated
      "max age" ago in seconds. A reasonable value is 2 weeks (`1209600`
      seconds);
    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000;
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32;
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256';

  """
  def verify(context, salt, token, opts \\ [])

  def verify(context, salt, token, opts) when is_binary(salt) and is_binary(token) do
    secret = get_key_base(context) |> get_secret(salt, opts)
    max_age_ms = if max_age_secs = opts[:max_age], do: trunc(max_age_secs * 1000)

    case MessageVerifier.verify(token, secret) do
      {:ok, message} ->
        %{data: data, signed: signed} = :erlang.binary_to_term(message)

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
    do: Phoenix.Controller.endpoint_module(conn).config(:secret_key_base)
  defp get_key_base(%Phoenix.Socket{} = socket),
    do: socket.endpoint.config(:secret_key_base)
  defp get_key_base(endpoint) when is_atom(endpoint),
    do: endpoint.config(:secret_key_base)
  defp get_key_base(string) when is_binary(string) and byte_size(string) >= 20,
    do: string

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

  defp now_ms, do: System.system_time(:milli_seconds)
end
