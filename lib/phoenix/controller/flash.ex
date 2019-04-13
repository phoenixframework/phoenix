defmodule Phoenix.Controller.Flash do
  import Plug.Conn

  @moduledoc false

  @session_key "phoenix_flash"
  @session_atom :phoenix_flash

  @doc false
  def fetch_flash(conn, _opts \\ []) do
    found_flash = get_session(conn, @session_key)
    conn = persist_flash(conn, found_flash || %{})

    register_before_send conn, fn conn ->
      flash = conn.private[@session_atom]
        || raise KeyError, key: @session_atom, term: conn.private
      flash_size = map_size(flash)

      cond do
        is_nil(found_flash) and flash_size == 0 ->
          conn
        flash_size > 0 and conn.status in 300..308 ->
          put_session(conn, @session_key, flash)
        true ->
          delete_session(conn, @session_key)
      end
    end
  end

  @doc false
  def clear_flash(conn) do
    persist_flash(conn, %{})
  end

  @doc false
  def put_flash(conn, key, message) do
    persist_flash(conn, Map.put(get_flash(conn), flash_key(key), message))
  end

  @doc false
  def get_flash(conn) do
    Map.get(conn.private, @session_atom) ||
      raise ArgumentError, message: "flash not fetched, call fetch_flash/2"
  end

  def get_flash(conn, key) do
    get_flash(conn)[flash_key(key)]
  end

  defp persist_flash(conn, value) do
    put_private(conn, @session_atom, value)
  end

  defp flash_key(binary) when is_binary(binary), do: binary
  defp flash_key(atom) when is_atom(atom), do: Atom.to_string(atom)

end
