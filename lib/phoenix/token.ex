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
    {secret, sign_secret} = get_endpoint_for(context) |> encryptor()
    MessageEncryptor.encrypt_and_sign(data, secret, sign_secret)
  end

  @doc """
    Decrypts the token into the originaly present data.
  """
  def verify_token(context, token) do
    {secret, sign_secret} = get_endpoint_for(context) |> encryptor()
    case MessageEncryptor.verify_and_decrypt(token, secret, sign_secret) do
      :error -> :error
      {:ok, data} -> 
    end
  end

  defp get_endpoint_for(conn = %Plug.Conn{}), do: Phoenix.Controller.endpoint_module(conn)
  defp get_endpoint_for(socket = %Phoenix.Socket{}), do: socket.endpoint

  # Gathers configuration and generates the key secrets and signing secrets.
  defp encryptor(endpoint) do
    config = endpoint.config(:token_auth)
    secret_key_base = Dict.get(config, :secret_key_base)
    encryption_salt = Dict.get(config, :encryption_salt)
    signing_salt = Dict.get(config, :signing_salt)

    secret = KeyGenerator.generate(secret_key_base, encryption_salt)
    sign_secret = KeyGenerator.generate(secret_key_base, signing_salt)
    {secret, sign_secret}
  end
end
