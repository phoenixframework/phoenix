defmodule Mix.PhoenixTest do
  use ExUnit.Case, async: true

  doctest Mix.Phoenix, import: true

  test "base/0 returns the module base based on the Mix application" do
    assert Mix.Phoenix.base() == "Phoenix"
    Application.put_env(:phoenix, :namespace, Phoenix.Sample.App)
    assert Mix.Phoenix.base() == "Phoenix.Sample.App"
  after
    Application.delete_env(:phoenix, :namespace)
  end

  test "modules/0 returns all modules in project" do
    assert Phoenix.Router in Mix.Phoenix.modules()
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
      "joined:naive_datetime",
      "token:uuid"
    ]
    assert Mix.Phoenix.Schema.attrs(attrs) == [
      logins: {:array, :string},
      age: :integer,
      temp: :float,
      temp_2: :decimal,
      admin: :boolean,
      meta: :map,
      name: :text,
      date_of_birth: :date,
      happy_hour: :time,
      joined: :naive_datetime,
      token: :uuid
    ]
  end

  test "attrs/1 raises with an unknown type" do
    assert_raise(Mix.Error, ~r"Unknown type `:other` given to generator", fn ->
      Mix.Phoenix.Schema.attrs(["other:other"])
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
      happy_hour_usec: :time_usec,
      joined: :naive_datetime,
      joined_utc: :utc_datetime,
      joined_utc_usec: :utc_datetime_usec,
      token: :uuid,
      other: :other
    ]

    assert Mix.Phoenix.Schema.params(params) == %{
             logins: [],
             age: 42,
             temp: 120.5,
             temp_2: "120.5",
             admin: true,
             meta: %{},
             name: "some name",
             date_of_birth: Date.add(Date.utc_today(), -1),
             happy_hour: ~T[14:00:00],
             happy_hour_usec: ~T[14:00:00.000000],
             joined: NaiveDateTime.truncate(build_utc_naive_datetime(), :second),
             joined_utc: DateTime.truncate(build_utc_datetime(), :second),
             joined_utc_usec: build_utc_datetime(),
             token: "7488a646-e31f-11e4-aace-600308960662",
             other: "some other"
           }
  end

  @one_day_in_seconds 24 * 3600

  defp build_utc_datetime,
    do: DateTime.add(%{DateTime.utc_now() | second: 0, microsecond: {0, 6}}, -@one_day_in_seconds)

  defp build_utc_naive_datetime,
    do:
      NaiveDateTime.add(
        %{NaiveDateTime.utc_now() | second: 0, microsecond: {0, 6}},
        -@one_day_in_seconds
      )

  test "live_form_value/1" do
    assert Mix.Phoenix.Schema.live_form_value(~D[2020-10-09]) == %{day: 9, month: 10, year: 2020}
    assert Mix.Phoenix.Schema.live_form_value(~T[14:00:00]) == %{hour: 14, minute: 00}

    assert Mix.Phoenix.Schema.live_form_value(~N[2020-10-09 14:00:00]) == %{
             day: 9,
             month: 10,
             year: 2020,
             hour: 14,
             minute: 00
           }

    assert Mix.Phoenix.Schema.live_form_value(~U[2020-10-09T14:00:00Z]) == %{
             day: 9,
             month: 10,
             year: 2020,
             hour: 14,
             minute: 00
           }

    assert Mix.Phoenix.Schema.live_form_value(:value) == :value
  end

  test "invalid_form_value/1" do
    assert ~D[2020-10-09]
           |> Mix.Phoenix.Schema.live_form_value()
           |> Mix.Phoenix.Schema.invalid_form_value() == %{day: 30, month: 2, year: 2020}

    assert ~T[14:00:00]
           |> Mix.Phoenix.Schema.live_form_value()
           |> Mix.Phoenix.Schema.invalid_form_value() == %{hour: 14, minute: 00}

    assert ~N[2020-10-09 14:00:00]
           |> Mix.Phoenix.Schema.live_form_value()
           |> Mix.Phoenix.Schema.invalid_form_value() == %{
             day: 30,
             month: 2,
             year: 2020,
             hour: 14,
             minute: 00
           }

    assert ~U[2020-10-09T14:00:00Z]
           |> Mix.Phoenix.Schema.live_form_value()
           |> Mix.Phoenix.Schema.invalid_form_value() == %{
             day: 30,
             month: 02,
             year: 2020,
             hour: 14,
             minute: 00
           }

    assert Mix.Phoenix.Schema.invalid_form_value(true) == false
    assert Mix.Phoenix.Schema.invalid_form_value(:anything) == nil
  end
end
