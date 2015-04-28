defmodule Phoenix.Token do
  @moduledoc """
  Tokens provide a way to  generate, verify, and decrypt bearer 
  tokens for use in Channels or API authentication. 

  ## Basic Usage
  When generating a unique token for usage in an API or Channel
  it is advised to use a unique identifier for the user typically
  the id from a Database. For example: 

      iex> user_id = 1
      iex> token = gen_token(endpoint, user_id)
      iex> user_id == verify_token(endpoint, token)
      true

  In that example we have a user's id, we generate a token and send
  it to the client. When the client uses the token in a futher 
  communication you verify the token, query the database and authorize 
  the user. 

  When using it with a socket a typical example might be:

    defmodule MyChannel do
      def join("my:" <> id = topic, %{token: token}, socket) do
        case verify_token(socket, token) do
        user_id ->
          socket = assigns(socket, :user, Repo.get!(User, user_id))
          reply socket, "join", %{}
        :expired -> {:error, :auth_expired, socket}                                                                                                                                                           
        :error -> {:error, :bad_auth, socket}
        end
      end
    end

  In this example the Phoenix.js client will be sending up the token
  in the join command. 

  If you want to provide an API to the user send it down to the user
  by generating it in a controller or view action. 

    def create(conn, params) do
      user = User.create(params)
      render conn, "user.json", %{token: gen_token(conn, user.id), user: user}
    end

    Then the client can use it all the way through. If you'd like to 
    use the same token for API authorization then I suggest adding it
    as a header to your authroized http requests
    
      Authorization: Bearer %{token}

    Then create a plug to verify the token and authorize with the database.

  """
  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageEncryptor

  @doc """
  Encrypts your data into a token you can send down to clients
  """
  def gen_token(context, data) do
    {secret, sign_secret, max_age, encoder} = get_endpoint(context) |> encryptor()
    message = %{ 
      data: data,
      exp: now_ms() + max_age
    } |> encoder.encode!()
    MessageEncryptor.encrypt_and_sign(message, secret, sign_secret)
  end

  @doc """
  Decrypts the token into the originaly present data.
  """
  def verify_token(context, token) do
    {secret, sign_secret, max_age, encoder} = get_endpoint(context) |> encryptor()
    case MessageEncryptor.verify_and_decrypt(token, secret, sign_secret) do
      :error -> :error
      {:ok, message} -> 
        %{ "data" => data, "exp" => exp} = Poison.decode!(message)
        if exp < now_ms() do
          :token_expired
        else
          data
        end
    end
  end

  defp get_endpoint(%Plug.Conn{} = conn), do: Phoenix.Controller.endpoint_module(conn)
  defp get_endpoint(%Phoenix.Socket{} = socket), do: socket.endpoint

  # Gathers configuration and generates the key secrets and signing secrets.
  defp encryptor(endpoint) do
    config = endpoint.config(:token_auth)
    secret_key_base = Dict.get(config, :secret_key_base)
    encryption_salt = Dict.get(config, :encryption_salt)
    signing_salt = Dict.get(config, :signing_salt)
    max_age_in_ms = Dict.get(config, :max_age)
    encoder =
      Application.get_env(:phoenix, :format_encoders)
      |> Keyword.get(:json, Poison)

    secret = KeyGenerator.generate(secret_key_base, encryption_salt)
    sign_secret = KeyGenerator.generate(secret_key_base, signing_salt)
    {secret, sign_secret, max_age_in_ms, encoder}
  end

  defp time_to_ms({mega, sec, micro}),
    do: ((((mega * 1000000) + sec) * 1000000) + micro) / 1000 |> trunc()
  defp now_ms, do: :os.timestamp() |> time_to_ms()
end
