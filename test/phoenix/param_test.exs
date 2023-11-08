defmodule Phoenix.ParamTest do
  use ExUnit.Case, async: true

  import Phoenix.Param

  test "to_param for integers" do
    assert to_param(1) == "1"
  end

  test "to_param for floats" do
    assert to_param(3.14) == "3.14"
  end

  test "to_param for binaries" do
    assert to_param("foo") == "foo"
  end

  test "to_param for atoms" do
    assert to_param(:foo) == "foo"
    assert to_param(true) == "true"
    assert to_param(false) == "false"
    assert_raise ArgumentError, fn -> to_param(nil) end
  end

  test "to_param for maps" do
    assert_raise ArgumentError, fn -> to_param(%{id: 1}) end
  end

  test "to_param for structs" do
    defmodule Test1 do
      defstruct [:id]
    end

    assert to_param(struct(Test1, id: 1)) == "1"
    assert to_param(struct(Test1, id: "foo")) == "foo"
  end

  test "to_param for derivable structs without key and id" do
    msg = ~r"cannot derive Phoenix.Param for struct Phoenix.ParamTest.Test2"

    assert_raise ArgumentError, msg, fn ->
      defmodule Test2 do
        @derive Phoenix.Param
        defstruct [:uuid]
      end
    end
  end

  test "to_param for derivable structs with key" do
    defmodule Test3 do
      @derive {Phoenix.Param, key: :uuid}
      defstruct [:uuid]
    end

    assert to_param(struct(Test3, uuid: 1)) == "1"
    assert to_param(struct(Test3, uuid: "foo")) == "foo"

    msg = ~r"cannot convert Phoenix.ParamTest.Test3 to param, key :uuid contains a nil value"

    assert_raise ArgumentError, msg, fn ->
      to_param(struct(Test3, uuid: nil))
    end
  end

  test "to_param for derivable structs with fun" do
    defmodule Test4 do
      @derive {Phoenix.Param, fun: &__MODULE__.uuid/1}
      defstruct [:uuid]

      def uuid(%__MODULE__{uuid: uuid}) do
        uuid
      end
    end

    assert to_param(struct(Test4, uuid: 1)) == "1"
    assert to_param(struct(Test4, uuid: "foo")) == "foo"

    msg =
      ~r"cannot convert Phoenix.ParamTest.Test4 to param, result of function &Phoenix.ParamTest.Test4.uuid/1 is a nil value"

    assert_raise ArgumentError, msg, fn ->
      to_param(struct(Test4, uuid: nil))
    end
  end
end
