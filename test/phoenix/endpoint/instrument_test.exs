defmodule Phoenix.Endpoint.InstrumentTest do
  use ExUnit.Case

  @config [instrumentation: [__MODULE__.MyInstrumenter, __MODULE__.MyOtherInstrumenter]]
  Application.put_env(:phoenix, __MODULE__.Endpoint, @config)

  defmodule MyInstrumenter do
    def my_event(:start, compile_meta, runtime_meta) do
      send self(), {:inst_start, %{compile_meta: compile_meta, runtime_meta: runtime_meta}}
      :ok
    end

    def my_event(:stop, duration, res) do
      send self(), {:inst_stop, %{result_from_start: res, duration: duration}}
    end

    def common_event(:start, _, _) do
      send self(), {__MODULE__, :common_event_start}
    end

    def common_event(:stop, _, _) do
      send self(), {__MODULE__, :common_event_stop}
    end
  end

  defmodule MyOtherInstrumenter do
    def common_event(:start, _, _) do
      send self(), {__MODULE__, :common_event_start}
    end

    def common_event(:stop, _, _) do
      send self(), {__MODULE__, :common_event_stop}
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  test "basic usage of instrument/3" do
    import Endpoint

    val = instrument :my_event, %{runtime: :ok}, fn ->
      send self(), :inside_instrument_block
      :normal_return_value
    end

    assert val == :normal_return_value

    assert_receive {:inst_start, start_data}
    assert start_data.compile_meta.file == __ENV__.file
    assert start_data.runtime_meta == %{runtime: :ok}

    assert_receive :inside_instrument_block

    assert_receive {:inst_stop, stop_data}
    assert stop_data.result_from_start == :ok
    assert is_integer(stop_data.duration)
    assert stop_data.duration > 0
  end

  test "raising inside the block passed to instrument/3" do
    import Endpoint

    assert_raise RuntimeError, "oops", fn ->
      instrument :my_event, %{runtime: :ok}, fn -> raise("oops") end
    end

    assert_receive {:inst_start, _}
    assert_receive {:inst_stop, _}
  end

  test "if no instrumenter is interested in an event, nothing is called" do
    import Endpoint

    instrument :uninteresting_event, fn ->
      send self(), :uninteresting_event_happened
    end

    assert_receive :uninteresting_event_happened
    refute_receive {:inst_start, _}
    refute_receive {:inst_stop, _}
  end

  test "multiple instrumenters interested in the same event" do
    import Endpoint

    instrument :common_event, fn ->
      send self(), :common_event_happened
    end

    assert_receive {__MODULE__.MyInstrumenter, :common_event_start}
    assert_receive {__MODULE__.MyOtherInstrumenter, :common_event_start}
    assert_receive :common_event_happened
    refute_receive :common_event_happened # just once!
    assert_receive {__MODULE__.MyInstrumenter, :common_event_stop}
    assert_receive {__MODULE__.MyOtherInstrumenter, :common_event_stop}
  end
end
