defmodule Phoenix.Token do
  @moduledoc """
  Will generate, verify, and decrypt tokens for use in channel or API 
  authentication. Typically you will want to store the basic information
  you need to authorize a user. Typically as simple as a user id in a 
  database. 

      iex> user_id = 1
      iex> token = encrypt(user_id, endpoint)
      iex> user_id == decrypt(token, endpoint)
      true
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
