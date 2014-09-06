defmodule Phoenix.Controller.PermitParamsTest do
  use ExUnit.Case
  use PlugHelper

  defmodule PermitParams.Controller do
    use Phoenix.Controller

    plug :permit_params, ["first_name", "last_name"]

    def test(conn, _params) do
      conn
    end
  end

  defmodule PermitParams.Router do
    use Phoenix.Router

    post "/permit/test", PermitParams.Controller, :test
  end

  test "permits all whitelisted params" do
    params = %{first_name: "Foo", last_name: "Bar"}
    conn = simulate_request(PermitParams.Router, :post, "permit/test", params)
    assert conn.params == %{"first_name" => "Foo", "last_name" => "Bar"}
  end

  test "blocks unpermitted params" do
    params = %{first_name: "Foo", username: "foobar", aka: "baz"}
    conn = simulate_request(PermitParams.Router, :post, "permit/test", params)
    assert conn.params == %{"first_name" => "Foo"}
  end
end
