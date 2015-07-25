defmodule Phoenix.Endpoint.Server do
  # The supervisor for the underlying handlers.
  @moduledoc false
  @handler Phoenix.Endpoint.CowboyHandler

  use Supervisor
  require Logger

  def start_link(otp_app, endpoint, opts \\ []) do
    Supervisor.start_link(__MODULE__, {otp_app, endpoint}, opts)
  end

  def init({otp_app, endpoint}) do
    import Supervisor.Spec

    children = []

    if config = endpoint.config(:http) do
      children =
        [@handler.child_spec(:http, endpoint, default(config, otp_app, 4000))|children]
    end

    if config = endpoint.config(:https) do
      {:ok, _} = Application.ensure_all_started(:ssl)
      children =
        [@handler.child_spec(:https, endpoint, default(config, otp_app, 4040))|children]
    end

    supervise(children, strategy: :one_for_one)
  end

  defp default(config, otp_app, port) do
    config =
      config
      |> Keyword.put_new(:otp_app, otp_app)
      |> Keyword.put_new(:port, port)

    Keyword.put(config, :port, to_port(config[:port]))
  end

  defp to_port(nil) do
    Logger.error "Server can't start because :port in config is nil, please use a valid port number"
    exit(:shutdown)
  end
  defp to_port(binary)  when is_binary(binary),   do: String.to_integer(binary)
  defp to_port(integer) when is_integer(integer), do: integer
  defp to_port({:system, env_var}), do: to_port(System.get_env(env_var))
end
