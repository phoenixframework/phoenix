defmodule Mix.PhoenixTest do
  use ExUnit.Case, async: true

  doctest Mix.Phoenix, import: true

  test "base/0 returns the module base based on the Mix application" do
    assert Mix.Phoenix.base == "Phoenix"
    Application.put_env(:phoenix, :namespace, Phoenix.Sample.App)
    assert Mix.Phoenix.base == "Phoenix.Sample.App"
  after
    Application.delete_env(:phoenix, :namespace)
  end

  test "modules/0 returns all modules in project" do
    assert Phoenix.Router in Mix.Phoenix.modules
  end

  test "attrs/1 defaults each type" do
    attrs = [
      "logins:array:string",
      "age:integer",
      "temp:float",
      "temp_2:decimal",
      "admin:boolean",
      "meta:map",
      "name:text",
      "date_of_birth:date",
      "happy_hour:time",
      "joined:datetime",
      "token:uuid"
    ]
    assert Mix.Phoenix.attrs(attrs) == [
      logins: {:array, :string},
      age: :integer,
      temp: :float,
      temp_2: :decimal,
      admin: :boolean,
      meta: :map,
      name: :text,
      date_of_birth: :date,
      happy_hour: :time,
      joined: :datetime,
      token: :uuid
    ]
  end

  test "attrs/1 raises with an unknown type" do
    assert_raise(Mix.Error, "Unknown type `other` given to generator", fn ->
      Mix.Phoenix.attrs(["other:other"])
    end)
  end

  test "params/1 defaults each type" do
    params = [
      logins: {:array, :string},
      age: :integer,
      temp: :float,
      temp_2: :decimal,
      admin: :boolean,
      meta: :map,
      name: :text,
      date_of_birth: :date,
      happy_hour: :time,
      joined: :datetime,
      token: :uuid,
      other: :other
    ]
    assert Mix.Phoenix.params(params) == %{
      logins: [],
      age: 42,
      temp: "120.5",
      temp_2: "120.5",
      admin: true,
      meta: %{},
      name: "some content",
      date_of_birth: %{year: 2010, month: 4, day: 17},
      happy_hour: %{hour: 14, min: 0, sec: 0},
      joined: %{year: 2010, month: 4, day: 17, hour: 14, min: 0, sec: 0},
      token: "7488a646-e31f-11e4-aace-600308960662",
      other: "some content"
    }
  end
end
