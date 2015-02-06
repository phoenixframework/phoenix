defmodule Phoenix.Endpoint.Supervisor do
  # The supervisor for the underlying handlers.
  @moduledoc false

  @handler Phoenix.Endpoint.CowboyHandler
  use Supervisor

  def start_link(otp_app, endpoint) do
    if endpoint.config(:server) || endpoint.config(:pubsub)[:adapter] do
      Supervisor.start_link(__MODULE__, {otp_app, endpoint})
    else
      :ignore
    end
  end

  def init({otp_app, endpoint}) do
    import Supervisor.Spec

    pubsub_conf = endpoint.config(:pubsub)
    children = []

    if endpoint.config(:server) do
      if config = endpoint.config(:http) do
        children =
          [@handler.child_spec(:http, endpoint, default(config, otp_app, 4000))|children]
      end

      if config = endpoint.config(:https) do
        {:ok, _} = Application.ensure_all_started(:ssl)
        children =
          [@handler.child_spec(:https, endpoint, default(config, otp_app, 4040))|children]
      end
    end

    if adapter = pubsub_conf[:adapter] do
      server_name = endpoint.__pubsub_server__()
      opts = pubsub_conf[:options] || []
      children =
        [supervisor(adapter, [server_name, opts]) | children]
    end

    supervise(children, strategy: :one_for_one)
  end

  defp default(config, otp_app, port) do
    config =
      config
      |> Keyword.put_new(:otp_app, otp_app)
      |> Keyword.put_new(:port, port)

    Keyword.put(config, :port, to_integer(config[:port]))
  end

  defp to_integer(binary)  when is_binary(binary),   do: String.to_integer(binary)
  defp to_integer(integer) when is_integer(integer), do: integer
end
