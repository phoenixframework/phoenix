defmodule Phoenix.InstrumentTest do
  use ExUnit.Case

  @config [instrumentation: [__MODULE__.MyInstrumenter]]
  Application.put_env(:phoenix, __MODULE__.Endpoint, @config)

  defmodule MyInstrumenter do
    def my_event(:start, compile_meta, runtime_meta) do
      send self(), {:inst_start, %{compile_meta: compile_meta, runtime_meta: runtime_meta}}
      :ok
    end

    def my_event(:stop, duration, res) do
      send self(), {:inst_stop, %{result_from_start: res, duration: duration}}
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
    use Phoenix.Instrument
  end

  test "basic usage of instrument/3" do
    import Endpoint

    val = instrument :my_event, :runtime_meta do
      send self(), :inside_instrument_block
      :normal_return_value
    end

    assert val == :normal_return_value

    assert_receive {:inst_start, start_data}
    current_file = __ENV__.file
    assert %Macro.Env{file: ^current_file} = start_data.compile_meta
    assert start_data.runtime_meta == :runtime_meta

    assert_receive :inside_instrument_block

    assert_receive {:inst_stop, stop_data}
    assert stop_data.result_from_start == :ok
    assert is_integer(stop_data.duration)
    assert stop_data.duration > 0
  end

  test "raising inside the block passed to instrument/3" do
    import Endpoint

    assert_raise RuntimeError, "oops", fn ->
      instrument :my_event, :runtime_meta, do: raise("oops")
    end

    assert_receive {:inst_start, _}
    assert_receive {:inst_stop, _}
  end

  test "if no instrumenter is interested in an event, nothing is called" do
    import Endpoint

    instrument :uninteresting_event, nil do
      send self(), :uninteresting_event_happened
    end

    refute_receive :uninteresting_event_happened
  end

  test "the event passed to instrument/3 has to be a compile-time atom" do
    import Endpoint

    msg = "the event passed to instrument/3 must be an atom"
    assert_raise ArgumentError, msg, fn ->
      Code.compile_quoted(quote do
        event = :event
        instrument event, nil, do: :ok
      end)
    end
  end
end
