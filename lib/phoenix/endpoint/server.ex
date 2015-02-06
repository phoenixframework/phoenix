defmodule Phoenix.Endpoint.Server do
  # The supervisor for the underlying handlers.
  @moduledoc false

  @handler Phoenix.Endpoint.CowboyHandler
  use Supervisor

  def start_link(otp_app, endpoint) do
    if endpoint.config(:server) do
      Supervisor.start_link(__MODULE__, {otp_app, endpoint})
    else
      :ignore
    end
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

    Keyword.put(config, :port, get_port_value(config[:port]))
  end

  defp get_port_value({ :dynamic, var_name }) do
    var_name |> System.get_env |> get_port_value
  end
  defp get_port_value(function) when is_function(function), do: function.() |> get_port_value
  defp get_port_value(binary)   when is_binary(binary),     do: String.to_integer(binary)
  defp get_port_value(integer)  when is_integer(integer),   do: integer
end
