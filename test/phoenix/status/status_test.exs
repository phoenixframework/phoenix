defmodule Phoenix.Status.StatusTest do
  use ExUnit.Case
  alias Phoenix.Status

  test "code converts atom to http status code" do
    assert Status.code(:ok) == 200
    assert Status.code(:request_uri_too_long) == 414
    assert Status.code(:variant_also_negotiates) == 506
    assert Status.code(:not_a_real_status) == nil
  end
end
