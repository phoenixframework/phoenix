defmodule Phoenix.Socket do
  @behaviour :cowboy_websocket_handler

  defmacro __using__(_) do
    quote do
      import Phoenix.Socket
    end
  end

  @doc """
  Cowboy callback to initialize an HTTP connection and begin the
  upgrade to WebSockets
  """
  def init({:tcp, :http}, req, _opts) do
    {upgrade, req} = :cowboy_req.header("upgrade", req)
    if String.downcase(upgrade) == "websocket" do
      {:upgrade, :protocol, :cowboy_websocket}
    else
      not_implemented(req)
    end
  end

  @doc """
  Cowboy callback to initialize a WebSocket connection
  """
  def websocket_init(any, req, _opts) do
    case __MODULE__.handle_open(any, req) do
      {:ok, req, state} ->
        req = :cowboy_req.compact(req)
        req = :cowboy_req.set_resp_header("sec-websocket-protocol", "umtp_1_0", req)
        {:ok, req, state, :hibernate}

      {:shutdown, req, _state} ->
        {:shutdown, req}
    end
  end

  @doc """
  Cowboy callback to handle a WebSocket message
  """
  def websocket_handle({:text, msg}, req, state) do
    case __MODULE__.handle_msg(msg, req, state) do
      {:ok, req, state} ->
        {:ok, req, state, :hibernate}

      {:reply, reply, req, state} ->
        {:reply, [text: reply], req, state, :hibernate}
    end
  end

  def websocket_handle(_any, req, state) do
    {:ok, req, state, :hibernate}
  end

  @doc """
  Cowboy callback to handle an Erlang message
  """
  def websocket_info(info, req, state) do
    case __MODULE__.handle_info(info, req, state) do
      {:ok, req, state} ->
        {:ok, req, state, :hibernate}

      {:reply, reply, req, state} ->
        {:reply, [text: reply], req, state, :hibernate}
    end
  end

  @doc """
  Cowboy callback to handle a terminated WebSocket connection
  """
  def websocket_terminate(reason, req, state) do
    __MODULE__.handle_close(reason, req, state)
  end

  @doc """
  Cowboy callback respond to an unimplemented protocol feature
  """
  def not_implemented(req) do
    { :ok, req } = :cowboy_req.reply(501, [], [], req)
    { :shutdown, req, :undefined }
  end
end
