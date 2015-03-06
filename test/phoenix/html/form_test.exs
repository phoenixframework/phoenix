defmodule Phoenix.HTML.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML
  import Phoenix.HTML.Form

  @conn Plug.Test.conn(:get, "/foo", %{"search" => %{
    "key" => "value",
    "datetime" => %{"year" => "2020", "month" => "4", "day" => "17",
                    "hour" => "2",   "min" => "11", "sec" => "13"}
  }})

  @doc """
  A function that executes `form_for/4` and
  extracts its inner contents for assertion.
  """
  def with_form(fun, opts \\ []) do
    mark = "--PLACEHOLDER--"

    {:safe, contents} =
      form_for(@conn, "/", [name: :search] ++ opts, fn f ->
        safe_concat [mark, fun.(f), mark]
      end)

    [_, inner, _] = String.split(IO.iodata_to_binary(contents), mark)
    {:safe, inner}
  end

  ## form_for/4

  test "form_for/4 with connection" do
    {:safe, form} = form_for(@conn, "/", [name: :search], fn f ->
      assert f.name == "search"
      assert f.source == @conn
      assert f.params["key"] == "value"
      ""
    end)

    assert form =~ ~s(<form accept-charset="UTF-8" action="/" method="post">)
    assert form =~ ~s(<input name="_utf8" type="hidden" value="✓">)
  end

  test "form_for/4 with custom options" do
    {:safe, form} = form_for(@conn, "/", [name: :search, method: :put, multipart: true], fn f ->
      refute f.options[:name]
      assert f.options[:multipart] == true
      assert f.options[:method] == :put
      ""
    end)

    assert form =~ ~s(<form accept-charset="UTF-8" action="/" enctype="multipart/form-data" method="post">)
    assert form =~ ~s(<input name="_method" type="hidden" value="put">)
  end

  test "form_for/4 is html safe" do
    {:safe, form} = form_for(@conn, "/", [name: :search], fn _ -> "<>" end)
    assert form =~ ~s(&lt;&gt;</form>)
  end

  ## text_input/3

  test "text_input/3" do
    assert text_input(:search, :key) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="text" value="">)}

    assert text_input(:search, :key, value: "foo", id: "key", name: "search[key][]") ==
           {:safe, ~s(<input id="key" name="search[key][]" type="text" value="foo">)}
  end

  test "text_input/3 with form" do
    assert with_form(&text_input(&1, :key)) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="text" value="value">)}

    assert with_form(&text_input(&1, :key, value: "foo", id: "key", name: "search[key][]")) ==
           {:safe, ~s(<input id="key" name="search[key][]" type="text" value="foo">)}
  end

  ## number_input/3

  test "number_input/3" do
    assert number_input(:search, :key) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="number" value="">)}

    assert number_input(:search, :key, value: "foo", id: "key", name: "search[key][]") ==
           {:safe, ~s(<input id="key" name="search[key][]" type="number" value="foo">)}
  end

  test "number_input/3 with form" do
    assert with_form(&number_input(&1, :key)) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="number" value="value">)}

    assert with_form(&number_input(&1, :key, value: "foo", id: "key", name: "search[key][]")) ==
           {:safe, ~s(<input id="key" name="search[key][]" type="number" value="foo">)}
  end

  ## hidden_input/3

  test "hidden_input/3" do
    assert hidden_input(:search, :key) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="hidden" value="">)}

    assert hidden_input(:search, :key, value: "foo", id: "key", name: "search[key][]") ==
           {:safe, ~s(<input id="key" name="search[key][]" type="hidden" value="foo">)}
  end

  test "hidden_input/3 with form" do
    assert with_form(&hidden_input(&1, :key)) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="hidden" value="value">)}

    assert with_form(&hidden_input(&1, :key, value: "foo", id: "key", name: "search[key][]")) ==
           {:safe, ~s(<input id="key" name="search[key][]" type="hidden" value="foo">)}
  end

  ## email_input/3

  test "email_input/3" do
    assert email_input(:search, :key) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="email" value="">)}

    assert email_input(:search, :key, value: "foo", id: "key", name: "search[key][]") ==
           {:safe, ~s(<input id="key" name="search[key][]" type="email" value="foo">)}
  end

  test "email_input/3 with form" do
    assert with_form(&email_input(&1, :key)) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="email" value="value">)}

    assert with_form(&email_input(&1, :key, value: "foo", id: "key", name: "search[key][]")) ==
           {:safe, ~s(<input id="key" name="search[key][]" type="email" value="foo">)}
  end

  ## file_input/3

  test "file_input/3" do
    assert file_input(:search, :key) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="file">)}

    assert file_input(:search, :key, id: "key", name: "search[key][]") ==
           {:safe, ~s(<input id="key" name="search[key][]" type="file">)}
  end

  test "file_input/3 with form" do
    assert_raise ArgumentError, fn ->
      with_form(&file_input(&1, :key))
    end

    assert with_form(&file_input(&1, :key), multipart: true) ==
           {:safe, ~s(<input id="search_key" name="search[key]" type="file">)}
  end

  ## submit/2

  test "submit/2" do
    assert submit("Submit") ==
           {:safe, ~s(<input type="submit" value="Submit">)}

    assert submit("Submit", class: "btn") ==
           {:safe, ~s(<input class="btn" type="submit" value="Submit">)}
  end

  ## radio_button/4

  test "radio_button/4" do
    assert radio_button(:search, :key, "admin") ==
           {:safe, ~s(<input id="search_key_admin" name="search[key]" type="radio" value="admin">)}

    assert radio_button(:search, :key, "admin", checked: true) ==
           {:safe, ~s(<input checked="checked" id="search_key_admin" name="search[key]" type="radio" value="admin">)}
  end

  test "radio_button/4 with form" do
    assert with_form(&radio_button(&1, :key, :admin)) ==
           {:safe, ~s(<input id="search_key_admin" name="search[key]" type="radio" value="admin">)}

    assert with_form(&radio_button(&1, :key, :value)) ==
           {:safe, ~s(<input checked="checked" id="search_key_value" name="search[key]" type="radio" value="value">)}

    assert with_form(&radio_button(&1, :key, :value, checked: false)) ==
           {:safe, ~s(<input id="search_key_value" name="search[key]" type="radio" value="value">)}
  end

  ## checkbox/3

  test "checkbox/3" do
    assert checkbox(:search, :key) ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="false">) <>
                   ~s(<input id="search_key" name="search[key]" type="checkbox" value="true">)}

    assert checkbox(:search, :key, value: "true") ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="false">) <>
                   ~s(<input checked="checked" id="search_key" name="search[key]" type="checkbox" value="true">)}

    assert checkbox(:search, :key, checked: true) ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="false">) <>
                   ~s(<input checked="checked" id="search_key" name="search[key]" type="checkbox" value="true">)}

    assert checkbox(:search, :key, value: "true", checked: false) ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="false">) <>
                   ~s(<input id="search_key" name="search[key]" type="checkbox" value="true">)}

    assert checkbox(:search, :key, value: 0, checked_value: 1, unchecked_value: 0) ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="0">) <>
                   ~s(<input id="search_key" name="search[key]" type="checkbox" value="1">)}

    assert checkbox(:search, :key, value: 1, checked_value: 1, unchecked_value: 0) ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="0">) <>
                   ~s(<input checked="checked" id="search_key" name="search[key]" type="checkbox" value="1">)}
  end

  test "checkbox/3 with form" do
    assert with_form(&checkbox(&1, :key)) ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="false">) <>
                   ~s(<input id="search_key" name="search[key]" type="checkbox" value="true">)}

    assert with_form(&checkbox(&1, :key, value: true)) ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="false">) <>
                   ~s(<input checked="checked" id="search_key" name="search[key]" type="checkbox" value="true">)}

    assert with_form(&checkbox(&1, :key, checked_value: :value, unchecked_value: :novalue)) ==
           {:safe, ~s(<input name="search[key]" type="hidden" value="novalue">) <>
                   ~s(<input checked="checked" id="search_key" name="search[key]" type="checkbox" value="value">)}
  end

  # select/4

  test "select/4" do
    assert select(:search, :key, ~w(foo bar)) ==
           {:safe, ~s(<select id="search_key" name="search[key]">) <>
                   ~s(<option value="foo">foo</option>) <>
                   ~s(<option value="bar">bar</option>) <>
                   ~s(</select>)}

    assert select(:search, :key, [foo: "Foo", bar: "Bar"]) ==
           {:safe, ~s(<select id="search_key" name="search[key]">) <>
                   ~s(<option value="foo">Foo</option>) <>
                   ~s(<option value="bar">Bar</option>) <>
                   ~s(</select>)}

    assert select(:search, :key, [foo: "Foo", bar: "Bar"], prompt: "Choose your destiny") ==
           {:safe, ~s(<select id="search_key" name="search[key]">) <>
                   ~s(<option value="">Choose your destiny</option>) <>
                   ~s(<option value="foo">Foo</option>) <>
                   ~s(<option value="bar">Bar</option>) <>
                   ~s(</select>)}

    {:safe, content} = select(:search, :key, ~w(foo bar), value: "foo")
    assert content =~ ~s(<option selected="selected" value="foo">foo</option>)

    {:safe, content} = select(:search, :key, ~w(foo bar), default: "foo")
    assert content =~ ~s(<option selected="selected" value="foo">foo</option>)
  end

test "select/4 with form" do
    assert with_form(&select(&1, :key, ~w(value novalue), default: "novalue")) ==
           {:safe, ~s(<select id="search_key" name="search[key]">) <>
                   ~s(<option selected="selected" value="value">value</option>) <>
                   ~s(<option value="novalue">novalue</option>) <>
                   ~s(</select>)}

    assert with_form(&select(&1, :other, ~w(value novalue), default: "novalue")) ==
           {:safe, ~s(<select id="search_other" name="search[other]">) <>
                   ~s(<option value="value">value</option>) <>
                   ~s(<option selected="selected" value="novalue">novalue</option>) <>
                   ~s(</select>)}

    assert with_form(&select(&1, :key, ~w(value novalue), value: "novalue")) ==
           {:safe, ~s(<select id="search_key" name="search[key]">) <>
                   ~s(<option value="value">value</option>) <>
                   ~s(<option selected="selected" value="novalue">novalue</option>) <>
                   ~s(</select>)}
  end

  # date_select/4

  test "date_select/4" do
    {:safe, content} = date_select(:search, :datetime)
    assert content =~ ~s(<select id="search_datetime_year" name="search[datetime][year]">)
    assert content =~ ~s(<select id="search_datetime_month" name="search[datetime][month]">)
    assert content =~ ~s(<select id="search_datetime_day" name="search[datetime][day]">)

    {:safe, content} = date_select(:search, :datetime, value: {2020, 04, 17})
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="4">April</option>)
    assert content =~ ~s(<option selected="selected" value="17">17</option>)

    {:safe, content} = date_select(:search, :datetime, value: %{year: 2020, month: 04, day: 07})
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="4">April</option>)
    assert content =~ ~s(<option selected="selected" value="7">07</option>)

    {:safe, content} = date_select(:search, :datetime, year: [prompt: "Year"],
                                   month: [prompt: "Month"], day: [prompt: "Day"])
    assert content =~ ~s(<select id="search_datetime_year" name="search[datetime][year]">) <>
                      ~s(<option value="">Year</option>)
    assert content =~ ~s(<select id="search_datetime_month" name="search[datetime][month]">) <>
                      ~s(<option value="">Month</option>)
    assert content =~ ~s(<select id="search_datetime_day" name="search[datetime][day]">) <>
                      ~s(<option value="">Day</option>)
  end

  test "date_select/4 with form" do
    {:safe, content} = with_form(&date_select(&1, :datetime, default: {2020, 10, 13}))
    assert content =~ ~s(<select id="search_datetime_year" name="search[datetime][year]">)
    assert content =~ ~s(<select id="search_datetime_month" name="search[datetime][month]">)
    assert content =~ ~s(<select id="search_datetime_day" name="search[datetime][day]">)
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="4">April</option>)
    assert content =~ ~s(<option selected="selected" value="17">17</option>)

    {:safe, content} = with_form(&date_select(&1, :unknown, default: {2020, 10, 13}))
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="10">October</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)

    {:safe, content} = with_form(&date_select(&1, :datetime, value: {2020, 10, 13}))
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="10">October</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)
  end

  # time_select/4

  test "time_select/4" do
    {:safe, content} = time_select(:search, :datetime)
    assert content =~ ~s(<select id="search_datetime_hour" name="search[datetime][hour]">)
    assert content =~ ~s(<select id="search_datetime_min" name="search[datetime][min]">)
    refute content =~ ~s(<select id="search_datetime_sec" name="search[datetime][sec]">)

    {:safe, content} = time_select(:search, :datetime, sec: [])
    assert content =~ ~s(<select id="search_datetime_hour" name="search[datetime][hour]">)
    assert content =~ ~s(<select id="search_datetime_min" name="search[datetime][min]">)
    assert content =~ ~s(<select id="search_datetime_sec" name="search[datetime][sec]">)

    {:safe, content} = time_select(:search, :datetime, value: {2, 11, 13}, sec: [])
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="11">11</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)

    {:safe, content} = time_select(:search, :datetime, value: {2, 11, 13, 328904}, sec: [])
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="11">11</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)

    {:safe, content} = time_select(:search, :datetime, value: %{hour: 2, min: 11, sec: 13}, sec: [])
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="11">11</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)

    {:safe, content} = time_select(:search, :datetime, hour: [prompt: "Hour"],
                                   min: [prompt: "Minute"], sec: [prompt: "Second"])
    assert content =~ ~s(<select id="search_datetime_hour" name="search[datetime][hour]">) <>
                      ~s(<option value="">Hour</option>)
    assert content =~ ~s(<select id="search_datetime_min" name="search[datetime][min]">) <>
                      ~s(<option value="">Minute</option>)
    assert content =~ ~s(<select id="search_datetime_sec" name="search[datetime][sec]">) <>
                      ~s(<option value="">Second</option>)
  end

  test "time_select/4 with form" do
    {:safe, content} = with_form(&time_select(&1, :datetime, default: {1, 2, 3}, sec: []))
    assert content =~ ~s(<select id="search_datetime_hour" name="search[datetime][hour]">)
    assert content =~ ~s(<select id="search_datetime_min" name="search[datetime][min]">)
    assert content =~ ~s(<select id="search_datetime_sec" name="search[datetime][sec]">)
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="11">11</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)

    {:safe, content} = with_form(&time_select(&1, :unknown, default: {1, 2, 3}, sec: []))
    assert content =~ ~s(<option selected="selected" value="1">01</option>)
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="3">03</option>)

    {:safe, content} = with_form(&time_select(&1, :datetime, value: {1, 2, 3}, sec: []))
    assert content =~ ~s(<option selected="selected" value="1">01</option>)
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="3">03</option>)
  end

  # datetime_select/4

  test "datetime_select/4" do
    {:safe, content} = datetime_select(:search, :datetime)
    assert content =~ ~s(<select id="search_datetime_year" name="search[datetime][year]">)
    assert content =~ ~s(<select id="search_datetime_month" name="search[datetime][month]">)
    assert content =~ ~s(<select id="search_datetime_day" name="search[datetime][day]">)
    assert content =~ ~s(<select id="search_datetime_hour" name="search[datetime][hour]">)
    assert content =~ ~s(<select id="search_datetime_min" name="search[datetime][min]">)
    refute content =~ ~s(<select id="search_datetime_sec" name="search[datetime][sec]">)

    {:safe, content} = datetime_select(:search, :datetime, sec: [])
    assert content =~ ~s(<select id="search_datetime_year" name="search[datetime][year]">)
    assert content =~ ~s(<select id="search_datetime_month" name="search[datetime][month]">)
    assert content =~ ~s(<select id="search_datetime_day" name="search[datetime][day]">)
    assert content =~ ~s(<select id="search_datetime_hour" name="search[datetime][hour]">)
    assert content =~ ~s(<select id="search_datetime_min" name="search[datetime][min]">)
    assert content =~ ~s(<select id="search_datetime_sec" name="search[datetime][sec]">)

    {:safe, content} = datetime_select(:search, :datetime, value: {{2020, 04, 17}, {2, 11, 13}}, sec: [])
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="4">April</option>)
    assert content =~ ~s(<option selected="selected" value="17">17</option>)
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="11">11</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)

    {:safe, content} = datetime_select(:search, :datetime, value: {{2020, 04, 17}, {2, 11, 13, 328904}}, sec: [])
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="4">April</option>)
    assert content =~ ~s(<option selected="selected" value="17">17</option>)
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="11">11</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)
  end

  test "datetime_select/4 with form" do
    {:safe, content} = with_form(&datetime_select(&1, :datetime, default: {{2020, 10, 13}, {1, 2, 3}}, sec: []))
    assert content =~ ~s(<select id="search_datetime_year" name="search[datetime][year]">)
    assert content =~ ~s(<select id="search_datetime_month" name="search[datetime][month]">)
    assert content =~ ~s(<select id="search_datetime_day" name="search[datetime][day]">)
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="4">April</option>)
    assert content =~ ~s(<option selected="selected" value="17">17</option>)

    assert content =~ ~s(<select id="search_datetime_hour" name="search[datetime][hour]">)
    assert content =~ ~s(<select id="search_datetime_min" name="search[datetime][min]">)
    assert content =~ ~s(<select id="search_datetime_sec" name="search[datetime][sec]">)
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="11">11</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)

    {:safe, content} = with_form(&datetime_select(&1, :unknown, default: {{2020, 10, 13}, {1, 2, 3}}, sec: []))
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="10">October</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)
    assert content =~ ~s(<option selected="selected" value="1">01</option>)
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="3">03</option>)

    {:safe, content} = with_form(&datetime_select(&1, :datetime, value: {{2020, 10, 13}, {1, 2, 3}}, sec: []))
    assert content =~ ~s(<option selected="selected" value="2020">2020</option>)
    assert content =~ ~s(<option selected="selected" value="10">October</option>)
    assert content =~ ~s(<option selected="selected" value="13">13</option>)
    assert content =~ ~s(<option selected="selected" value="1">01</option>)
    assert content =~ ~s(<option selected="selected" value="2">02</option>)
    assert content =~ ~s(<option selected="selected" value="3">03</option>)
  end

  test "datetime_select/4 with builder" do
    builder = fn b ->
      safe_concat ["Year: ",  b.(:year, class: "year"),
                   "Month: ", b.(:month, class: "month"),
                   "Day: ",   b.(:day, class: "day"),
                   "Hour: ",  b.(:hour, class: "hour"),
                   "Min: ",   b.(:min, class: "min"),
                   "Sec: ",   b.(:sec, class: "sec")]
    end

    {:safe, content} = datetime_select(:search, :datetime, builder: builder,
                                       year: [id: "year"], month: [id: "month"],
                                       day: [id: "day"], hour: [id: "hour"],
                                       min: [id: "min"], sec: [id: "sec"])

    assert content =~ ~s(Year: <select class="year" id="year" name="search[datetime][year]">)
    assert content =~ ~s(Month: <select class="month" id="month" name="search[datetime][month]">)
    assert content =~ ~s(Day: <select class="day" id="day" name="search[datetime][day]">)
    assert content =~ ~s(Hour: <select class="hour" id="hour" name="search[datetime][hour]">)
    assert content =~ ~s(Min: <select class="min" id="min" name="search[datetime][min]">)
    assert content =~ ~s(Sec: <select class="sec" id="sec" name="search[datetime][sec]">)
  end
end
