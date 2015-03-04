defmodule Phoenix.HTML.FormTest do
  use ExUnit.Case, async: true
  import Phoenix.HTML.Form

  @conn Plug.Test.conn(:get, "/foo", %{"search" => %{"key" => "value"}})

  @doc """
  A function that executes `form_for/4` and
  extracts its inner contents for assertion.
  """
  def with_form(fun) do
    mark = "--PLACEHOLDER--"

    {:safe, contents} =
      form_for(@conn, "/", [name: :search], fn f ->
        Phoenix.HTML.safe_concat [mark, fun.(f), mark]
      end)

    [_, inner, _] = String.split(IO.iodata_to_binary(contents), mark)
    {:safe, inner}
  end

  ## form_for/4

  test "form_for/4 with connection" do
    {:safe, form} = form_for(@conn, "/", [name: :search], fn f ->
      assert f.name   == "search"
      assert f.params == %{"key" => "value"}
      assert f.method == "post"
      ""
    end)

    assert form =~ ~s(<form accept-charset="UTF-8" action="/" method="post">)
    assert form =~ ~s(<input name="_utf8" type="hidden" value="✓">)
  end

  test "form_for/4 with custom options" do
    {:safe, form} = form_for(@conn, "/", [name: :search, method: :put, multipart: true], fn f ->
      assert f.method == "put"
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
end
