defmodule MyApp.PermitParamsController do
  use Phoenix.Controller

  plug :permit_params, ["first_name", "last_name"]

  def test(conn, params), do: conn
end

defmodule MyApp.Router do
  use Phoenix.Router

  post "/permit/test", MyApp.PermitParamsController, :test
end

defmodule Phoenix.Controller.PermitParamsTest do
  use ExUnit.Case
  use PlugHelper

  test "permits all whitelisted params" do
    params = %{first_name: "Foo", last_name: "Bar"}
    conn = simulate_request(MyApp.Router, :post, "permit/test", params)
    assert conn.params == %{"first_name" => "Foo", "last_name" => "Bar"}
  end

  test "blocks unpermitted params" do
    params = %{first_name: "Foo", username: "foobar", aka: "baz"}
    conn = simulate_request(MyApp.Router, :post, "permit/test", params)
    assert conn.params == %{"first_name" => "Foo"}
  end
end
