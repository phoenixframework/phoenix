defmodule Phoenix.Token do
  @moduledoc """
  Tokens provide a way to  generate, verify, and decrypt bearer
  tokens for use in Channels or API authentication.

  ## Basic Usage
  When generating a unique token for usage in an API or Channel
  it is advised to use a unique identifier for the user typically
  the id from a Database. For example:

      iex> user_id = 1
      iex> token = sign_token(endpoint, "user", user_id)
      iex> user_id == verify_token(endpoint, token)
      true

  In that example we have a user's id, we generate a token and send
  it to the client. When the client uses the token in a futher
  communication you verify the token, query the database and authorize
  the user.

  When using it with a socket a typical example might be:

    defmodule MyChannel do
      def join("my:" <> id = topic, %{token: token}, socket) do
        case verify_token(socket, "user", token) do
          user_id ->
            socket = assigns(socket, :user, Repo.get!(User, user_id))
            reply socket, "join", %{}
          {:error, :expired} -> :ignore
          {:error, :invalid} -> :ignore
        end
      end
    end

  In this example the Phoenix.js client will be sending up the token
  in the join command.

  If you want to provide an API to the user send it down to the user
  by generating it in a controller or view action.

    def create(conn, params) do
      user = User.create(params)
      render conn, "user.json", %{token: sign_token(conn, "user", user.id), user: user}
    end

    Then the client can use it all the way through. If you'd like to
    use the same token for API authorization then I suggest adding it
    as a header to your authroized http requests

      Authorization: Bearer #\{token}

    Then create a plug to verify the token and authorize with the database.

  """
  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier

  @doc """
  Signs your data into a token you can send down to clients

  ## Options
    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000;
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32;
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256';
  """
  def sign_token(context, salt,  data, opts \\ []) when is_binary(data) or is_integer(data) or is_map(data) do
    secret = get_endpoint(context) |> get_secret(salt, opts)

    message = %{
      data: data,
      signed: now_ms()
    } |> :erlang.term_to_binary()
    MessageVerifier.sign(message, secret)
  end

  @doc """
  Decrypts the token into the originaly present data.

  ## Options
    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000;
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32;
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256';
  """
  def verify_token(context, salt, token, opts \\ []) do
    secret = get_endpoint(context) |> get_secret(salt, opts)
    case MessageVerifier.verify(token, secret) do
      :error -> {:error, :invalid}
      {:ok, message} ->
        %{data: data, signed: signed} = :erlang.binary_to_term(message)

        max_age = if Dict.has_key?(opts, :max_age) do
          opts[:max_age]
        end

        if max_age && (signed + max_age) < now_ms() do
          {:error, :expired}
        else
          data
        end
    end
  end

  defp get_endpoint(%Plug.Conn{} = conn), do: Phoenix.Controller.endpoint_module(conn)
  defp get_endpoint(%Phoenix.Socket{} = socket), do: socket.endpoint

  # Gathers configuration and generates the key secrets and signing secrets.
  defp get_secret(endpoint, salt, opts \\ []) do
    secret_key_base = endpoint.config(:secret_key_base)
    iterations = Keyword.get(opts, :key_iterations, 1000)
    length = Keyword.get(opts, :key_length, 32)
    digest = Keyword.get(opts, :key_digest, :sha256)
    key_opts = [iterations: iterations,
                length: length,
                digest: digest,
                cache: Plug.Keys]
    KeyGenerator.generate(secret_key_base, salt, key_opts)
  end

  defp time_to_ms({mega, sec, micro}),
    do: ((((mega * 1000000) + sec) * 1000000) + micro) / 1000 |> trunc()
  defp now_ms, do: :os.timestamp() |> time_to_ms()
end
