defmodule Phoenix.MissingParamError do
  defexception [:message]

  def exception([key: value]) do
    msg = "Expected key for #{inspect value} to be present."
    %Phoenix.MissingParamError{message: msg}
  end
end

defmodule ScrubberTest do
  use ExUnit.Case, async: true
  use Plug.Test

  def scrub_params(conn, required_key) do
    conn = Plug.Conn.fetch_params(conn)

    unless Map.has_key?(conn.params, required_key) do
      raise Phoenix.MissingParamError, key: required_key
    end

    params = Enum.reduce(conn.params, %{}, fn({k, v}, acc) ->
      case v do
        "" -> Map.put(acc, k, nil)
        _ -> Map.put(acc, k, v)
      end
    end)

    %{conn | params: params}
  end

  test "scrub_params/2 raises Phoenix.MissingParamError with key as the required_key when it's missing from the params" do
    conn = conn(:get, "/?foo=bar")

    assert_raise(Phoenix.MissingParamError, "Expected key for \"present\" to be present.", fn ->
      scrub_params(conn, "present")
    end)
  end

  test "scrub_params/2 keeps populated keys intact" do
    conn = conn(:get, "/?foo=bar&baz=qux")
    |> scrub_params("foo")

    assert conn.params["foo"] == "bar"
    assert conn.params["baz"] == "qux"
  end

  test "scrub_params/2 nils out keys with empty values" do
    conn = conn(:get, "/?foo=bar&baz=")
    |> scrub_params("foo")

    assert conn.params["foo"] == "bar"
    assert conn.params["baz"] == nil
  end

  test "scrub_params/2 allows the required key to be empty and nils it out" do
    conn = conn(:get, "/?foo=&baz=qux")
    |> scrub_params("foo")

    assert conn.params["foo"] == nil
    assert conn.params["baz"] == "qux"
  end
end
