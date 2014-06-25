defmodule Phoenix.Mime.MimeTest do
  use ExUnit.Case
  alias Phoenix.Mime

  test "ext_from_type converts content type to extension" do
    assert Mime.ext_from_type("text/html") == ".html"
    assert Mime.ext_from_type("text/csv") == ".csv"
    assert Mime.ext_from_type("application/json") == ".json"
    assert Mime.ext_from_type("NOTFOUND") == nil
    assert Mime.ext_from_type("") == nil
  end

  test "type_from_ext converts extension to content type" do
    assert Mime.type_from_ext(".html") == "text/html"
    assert Mime.type_from_ext(".csv") == "text/csv"
    assert Mime.type_from_ext(".json") == "application/json"
    assert Mime.type_from_ext(".notfound") == nil
    assert Mime.type_from_ext("") == nil
  end

  test "valid_type? returns true when mime is known" do
    assert Mime.valid_type?("text/html")
  end

  test "valid_type? returns false when mime is not known" do
    refute Mime.valid_type?("unknown/type")
  end
end

