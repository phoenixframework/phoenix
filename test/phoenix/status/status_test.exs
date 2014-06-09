defmodule Phoenix.Status.StatusTest do
  use ExUnit.Case
  alias Phoenix.Status

  test "code converts atom to http status code" do
    assert Status.code(:ok) == 200
    assert Status.code(:request_uri_too_long) == 414
    assert Status.code(:variant_also_negotiates) == 506
    assert_raise Phoenix.Status.InvalidStatus, "invalid http status atom :not_a_real_status", fn ->
      Status.code(:not_a_real_status)
    end
  end

  test "code passes integer status codes through, valid or not" do
    assert Status.code(200) == 200
    assert Status.code(414) == 414
    assert Status.code(506) == 506
    assert Status.code(1337) == 1337
  end
end
